class ProcessInboundMessageJob < ApplicationJob
  queue_as :default

  def perform(msg)
    conversation = Conversation.find_or_create_for(
      msg["from"],
      contact_name: msg["contact_name"]
    )

    # Skip duplicate deliveries (WhatsApp can retry webhooks)
    return if msg["whatsapp_id"] && Message.exists?(whatsapp_message_id: msg["whatsapp_id"])

    whatsapp = Whatsapp::Client.new
    broker   = Broker.first

    case msg["type"]
    when "text"
      text = msg["text"].to_s.strip
      return if text.blank?

      save_message(conversation, role: "user", content: text, type: "text", wa_id: msg["whatsapp_id"])
      reply = Agent::PropertyBrokerService.new(conversation, broker: broker).call(text)
      send_and_save_reply(conversation, whatsapp, msg["from"], reply)

    when "audio"
      media_id = msg["audio_media_id"]
      return unless media_id

      whatsapp.send_text(to: msg["from"], body: "Got it, one moment...")

      audio_data = whatsapp.download_media(media_id)
      return unless audio_data

      transcript = Openai::TranscriptionService.new.transcribe(audio_data)
      return if transcript.blank?

      save_message(conversation, role: "user", content: transcript, type: "audio", wa_id: msg["whatsapp_id"], media_id: media_id)
      reply = Agent::PropertyBrokerService.new(conversation, broker: broker).call(transcript)
      send_and_save_reply(conversation, whatsapp, msg["from"], reply)
    end
  end

  private

  def save_message(conversation, role:, content:, type:, wa_id: nil, media_id: nil)
    conversation.messages.create!(
      role:                role,
      content:             content,
      message_type:        type,
      whatsapp_message_id: wa_id,
      media_id:            media_id
    )
  end

  def send_and_save_reply(conversation, whatsapp, to, text)
    return if text.blank?

    whatsapp.send_text(to: to, body: text)
    conversation.messages.create!(role: "assistant", content: text, message_type: "text")
  end
end
