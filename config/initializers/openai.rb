OpenAI.configure do |config|
  config.access_token   = ENV.fetch("OPENAI_API_KEY", "placeholder_key")
  config.request_timeout = 120
end
