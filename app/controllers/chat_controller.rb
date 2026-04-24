class ChatController < ApplicationController
  TEST_PHONE = "browser_test_user"

  def index
    @conversation = Conversation.find_or_create_for(TEST_PHONE, contact_name: "Test Broker")
    @messages     = @conversation.recent_messages(50)
  end

  def message
    conversation = Conversation.find_or_create_for(TEST_PHONE, contact_name: "Test Broker")
    text         = params[:text].to_s.strip

    return render json: { error: "Empty message" }, status: :unprocessable_entity if text.blank?

    conversation.messages.create!(role: "user", content: text, message_type: "text")

    reply = Agent::PropertyBrokerService.new(conversation, broker: current_broker).call(text)
    conversation.messages.create!(role: "assistant", content: reply, message_type: "text")

    render json: { reply: reply }
  end

  def voice
    conversation = Conversation.find_or_create_for(TEST_PHONE, contact_name: "Test Broker")
    audio        = params[:audio]

    return render json: { error: "No audio file" }, status: :unprocessable_entity unless audio

    transcript = Openai::TranscriptionService.new.transcribe(
      audio.read,
      mime_type: audio.content_type
    )

    return render json: { error: "Could not transcribe audio" }, status: :unprocessable_entity if transcript.blank?

    conversation.messages.create!(role: "user", content: transcript, message_type: "audio")

    reply = Agent::PropertyBrokerService.new(conversation, broker: current_broker).call(transcript)
    conversation.messages.create!(role: "assistant", content: reply, message_type: "text")

    render json: { transcript: transcript, reply: reply }
  end

  def reset
    Conversation.find_by(phone_number: TEST_PHONE)&.destroy
    redirect_to chat_path
  end
end
