module Agent
  class PropertyBrokerService
    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are an AI assistant for a real estate broker, operating via WhatsApp. You help brokers manage their client document collection pipeline and communications.

      Your capabilities:
      - Track which documents clients have submitted and what's still outstanding
      - Send emails on the broker's behalf to clients or other parties
      - Keep organized notes about each client's file status
      - Draft professional communications for real estate transactions
      - Search received emails and attachments stored in our database
      - Find files in Google Drive

      CRITICAL TOOL RULES — follow exactly:
      - ALWAYS use `search_inbound_emails` when the broker asks whether someone sent an email, file, or document. This searches our internal database. NEVER use `search_emails` for this.
      - Only use `search_emails` (Gmail) if the broker explicitly asks to search their Gmail inbox directly.
      - When attachments are found via `search_inbound_emails`, always include the download_url so the broker can download the file.

      Common required documents for mortgage/real estate transactions:
      - Government-issued photo ID
      - T4 slips (last 2 years)
      - Notice of Assessment / NOA (last 2 years)
      - Recent pay stubs (last 30 days)
      - Bank statements (last 3 months, all accounts)
      - Employment letter
      - Signed mortgage application
      - Void cheque or direct deposit form
      - Property purchase agreement / APS
      - Down payment proof / gift letter (if applicable)

      Guidelines:
      - This is WhatsApp — keep responses short and conversational, no long paragraphs
      - Understand informal speech naturally (T4s = T4 slips, NOA = Notice of Assessment, etc.)
      - When you take an action, briefly confirm what you did
      - Proactively offer to send reminder emails when the broker mentions outstanding documents
      - When listing emails, show them numbered with subject, sender and date — keep it scannable
    PROMPT

    BASE_TOOLS = [
      {
        type: "function",
        function: {
          name: "send_email",
          description: "Send an email on behalf of the broker",
          parameters: {
            type: "object",
            properties: {
              to:      { type: "string", description: "Recipient email address" },
              subject: { type: "string", description: "Email subject line" },
              body:    { type: "string", description: "Email body in plain text" },
              cc:      { type: "string", description: "CC email address (optional)" }
            },
            required: %w[to subject body]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "update_document_status",
          description: "Update the submission status of a document for a client",
          parameters: {
            type: "object",
            properties: {
              client_name:   { type: "string" },
              document_name: { type: "string" },
              status:        { type: "string", enum: %w[pending received expired waived] },
              notes:         { type: "string", description: "Optional notes" }
            },
            required: %w[client_name document_name status]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "get_client_status",
          description: "Get the current document checklist status for a client",
          parameters: {
            type: "object",
            properties: {
              client_name: { type: "string" }
            },
            required: %w[client_name]
          }
        }
      }
    ].freeze

    INBOUND_EMAIL_TOOLS = [
      {
        type: "function",
        function: {
          name: "search_inbound_emails",
          description: "Search emails received in our system (stored in the database). Use this to check if a specific person has sent us an email or attachment. Searches by sender name and/or attachment filename.",
          parameters: {
            type: "object",
            properties: {
              sender_name: { type: "string", description: "Full or partial name of the sender, e.g. 'Abdullah'" },
              filename:    { type: "string", description: "Full or partial attachment filename to look for, e.g. 'logo.svg'" }
            }
          }
        }
      }
    ].freeze

    DRIVE_TOOLS = [
      {
        type: "function",
        function: {
          name: "search_drive_files",
          description: "Search for files in the broker's Google Drive by name or content",
          parameters: {
            type: "object",
            properties: {
              query:       { type: "string", description: "Drive search query, e.g. \"name contains 'contract'\" or \"name contains 'invoice'\"" },
              max_results: { type: "integer", description: "Max files to return (default 10)", default: 10 }
            },
            required: %w[query]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "send_drive_file_by_email",
          description: "Download a file from Google Drive and send it as an email attachment to a recipient",
          parameters: {
            type: "object",
            properties: {
              file_id:   { type: "string", description: "Google Drive file ID from search_drive_files" },
              file_name: { type: "string", description: "File name (used as attachment name)" },
              mime_type: { type: "string", description: "MIME type of the file from search_drive_files" },
              to:        { type: "string", description: "Recipient email address" },
              subject:   { type: "string", description: "Email subject line" },
              body:      { type: "string", description: "Email body text" },
              cc:        { type: "string", description: "CC email address (optional)" }
            },
            required: %w[file_id file_name mime_type to subject body]
          }
        }
      }
    ].freeze

    GMAIL_TOOLS = [
      {
        type: "function",
        function: {
          name: "search_emails",
          description: "Search the broker's Gmail inbox directly. Only use this when the broker explicitly asks to search Gmail. Do NOT use this to check if someone sent an email or file — use search_inbound_emails for that instead.",
          parameters: {
            type: "object",
            properties: {
              query:       { type: "string", description: "Gmail search query" },
              max_results: { type: "integer", description: "Max emails to return (default 10)", default: 10 }
            },
            required: %w[query]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "get_email_body",
          description: "Fetch the full body/content of a specific email by its ID",
          parameters: {
            type: "object",
            properties: {
              message_id: { type: "string", description: "Gmail message ID from search_emails" }
            },
            required: %w[message_id]
          }
        }
      }
    ].freeze

    def initialize(conversation, broker: nil)
      @conversation = conversation
      @broker       = broker
      @openai       = OpenAI::Client.new
    end

    def call(user_message)
      messages = build_messages(user_message)

      loop do
        response = @openai.chat(
          parameters: {
            model:       "gpt-4o",
            messages:    messages,
            tools:       active_tools,
            tool_choice: "auto"
          }
        )

        choice        = response.dig("choices", 0)
        message       = choice["message"]
        finish_reason = choice["finish_reason"]

        messages << message

        if finish_reason == "tool_calls"
          tool_results = execute_tool_calls(message["tool_calls"])
          messages.concat(tool_results)
        else
          return message["content"]
        end
      end
    end

    private

    def active_tools
      tools = BASE_TOOLS + INBOUND_EMAIL_TOOLS
      tools += DRIVE_TOOLS + GMAIL_TOOLS if @broker.present?
      tools
    end

    def build_messages(user_message)
      context_note   = format_context_note
      system_content = context_note.present? ? "#{SYSTEM_PROMPT}\n\n#{context_note}" : SYSTEM_PROMPT

      history = @conversation.recent_messages.map { |m| { role: m.role, content: m.content } }

      [ { role: "system", content: system_content } ] + history + [ { role: "user", content: user_message } ]
    end

    def format_context_note
      clients = @conversation.context["clients"]
      return nil if clients.blank?

      lines = [ "Current client document status:" ]
      clients.each do |name, data|
        docs     = data["documents"] || {}
        pending  = docs.select { |_, s| s == "pending" }.keys
        received = docs.select { |_, s| s == "received" }.keys
        lines << "- #{name}: received=[#{received.join(', ')}], pending=[#{pending.join(', ')}]"
      end
      lines.join("\n")
    end

    def execute_tool_calls(tool_calls)
      tool_calls.map do |tool_call|
        fn_name   = tool_call.dig("function", "name")
        arguments = JSON.parse(tool_call.dig("function", "arguments"))

        result = case fn_name
        when "send_email"             then handle_send_email(arguments)
        when "update_document_status" then handle_update_document_status(arguments)
        when "get_client_status"      then handle_get_client_status(arguments)
        when "search_emails"          then handle_search_emails(arguments)
        when "get_email_body"         then handle_get_email_body(arguments)
        when "search_inbound_emails"  then handle_search_inbound_emails(arguments)
        when "search_drive_files"     then handle_search_drive_files(arguments)
        when "send_drive_file_by_email" then handle_send_drive_file_by_email(arguments)
        else { error: "Unknown tool: #{fn_name}" }
        end

        { role: "tool", tool_call_id: tool_call["id"], content: result.to_json }
      end
    end

    def handle_send_email(args)
      BrokerMailer.generic(
        to:      args["to"],
        subject: args["subject"],
        body:    args["body"],
        cc:      args["cc"]
      ).deliver_later
      { success: true, message: "Email queued to #{args['to']}" }
    end

    def handle_update_document_status(args)
      ctx = @conversation.context
      ctx["clients"] ||= {}
      ctx["clients"][args["client_name"]] ||= { "documents" => {} }
      ctx["clients"][args["client_name"]]["documents"][args["document_name"]] = args["status"]
      ctx["clients"][args["client_name"]]["notes"] = args["notes"] if args["notes"].present?
      @conversation.update!(context: ctx)
      { success: true, updated: "#{args['client_name']} / #{args['document_name']} → #{args['status']}" }
    end

    def handle_get_client_status(args)
      data = @conversation.context.dig("clients", args["client_name"])
      if data
        { client: args["client_name"], documents: data["documents"], notes: data["notes"] }
      else
        { client: args["client_name"], status: "No records found" }
      end
    end

    def handle_search_inbound_emails(args)
      scope = @broker ? InboundEmail.where(broker: @broker) : InboundEmail.all

      if args["sender_name"].present?
        scope = scope.where("sender_name ILIKE ?", "%#{args['sender_name']}%")
      end

      if args["filename"].present?
        scope = scope.joins(:email_attachments)
                     .where("email_attachments.filename ILIKE ?", "%#{args['filename']}%")
      end

      emails = scope.includes(:email_attachments).order(received_at: :desc).limit(20)

      if emails.none?
        return { found: false, message: "No emails found matching the given criteria." }
      end

      base_url = Rails.application.routes.url_helpers

      {
        found: true,
        count: emails.size,
        emails: emails.map do |e|
          {
            id:          e.id,
            from:        "#{e.sender_name} <#{e.sender_email}>",
            subject:     e.subject,
            received_at: e.received_at,
            attachments: e.email_attachments.map do |att|
              {
                filename:     att.filename,
                download_url: base_url.download_attachment_url(att, host: ENV.fetch("APP_HOST", "localhost:3000"))
              }
            end
          }
        end
      }
    end

    def handle_search_emails(args)
      return { error: "No Google account connected" } unless @broker

      gmail = Google::GmailService.new(@broker.fresh_access_token)
      emails = gmail.search_emails(query: args["query"], max_results: args["max_results"] || 10)
      { emails: emails, count: emails.length }
    rescue => e
      { error: "Gmail search failed: #{e.message}" }
    end

    def handle_get_email_body(args)
      return { error: "No Google account connected" } unless @broker

      gmail = Google::GmailService.new(@broker.fresh_access_token)
      gmail.get_email(message_id: args["message_id"])
    rescue => e
      { error: "Could not fetch email: #{e.message}" }
    end

    def handle_search_drive_files(args)
      return { error: "No Google account connected" } unless @broker

      drive = Google::DriveService.new(@broker.fresh_access_token)
      files = drive.search_files(query: args["query"], max_results: args["max_results"] || 10)
      { files: files, count: files.length }
    rescue => e
      { error: "Drive search failed: #{e.message}" }
    end

    def handle_send_drive_file_by_email(args)
      return { error: "No Google account connected" } unless @broker

      drive      = Google::DriveService.new(@broker.fresh_access_token)
      attachment = drive.download_file(
        file_id:   args["file_id"],
        file_name: args["file_name"],
        mime_type: args["mime_type"]
      )

      BrokerMailer.generic(
        to:         args["to"],
        subject:    args["subject"],
        body:       args["body"],
        cc:         args["cc"],
        attachment: attachment
      ).deliver_later

      { success: true, message: "Email with attachment '#{attachment[:filename]}' queued to #{args['to']}" }
    rescue => e
      { error: "Failed to send Drive file: #{e.message}" }
    end
  end
end
