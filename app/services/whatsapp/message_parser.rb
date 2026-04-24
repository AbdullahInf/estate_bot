module Whatsapp
  class MessageParser
    def self.extract_messages(payload)
      messages = []

      Array(payload["entry"]).each do |entry|
        Array(entry["changes"]).each do |change|
          next unless change["field"] == "messages"

          value    = change["value"]
          metadata = value["metadata"] || {}
          contacts = value["contacts"] || []

          Array(value["messages"]).each do |msg|
            contact     = contacts.find { |c| c["wa_id"] == msg["from"] } || {}
            contact_name = contact.dig("profile", "name")

            messages << {
              "from"            => msg["from"],
              "contact_name"    => contact_name,
              "whatsapp_id"     => msg["id"],
              "timestamp"       => msg["timestamp"],
              "type"            => msg["type"],
              "text"            => msg.dig("text", "body"),
              "audio_media_id"  => msg.dig("audio", "id"),
              "phone_number_id" => metadata["phone_number_id"]
            }
          end
        end
      end

      messages
    end
  end
end
