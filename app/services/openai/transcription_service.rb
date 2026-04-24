module Openai
  class TranscriptionService
    def initialize
      @client = OpenAI::Client.new
    end

    def transcribe(audio_data, mime_type: "audio/ogg")
      extension = extension_for(mime_type)

      Tempfile.create([ "voice_note", extension ]) do |file|
        file.binmode
        file.write(audio_data)
        file.rewind

        response = @client.audio.transcribe(
          parameters: {
            model: "whisper-1",
            file: file,
            language: "en"
          }
        )

        response["text"]
      end
    end

    private

    def extension_for(mime_type)
      case mime_type
      when /opus/ then ".opus"
      when /ogg/  then ".ogg"
      when /mp4/  then ".mp4"
      when /mpeg/ then ".mp3"
      else ".ogg"
      end
    end
  end
end
