# Estate Bot

WhatsApp-based AI property broker assistant. Brokers speak to the bot via WhatsApp (text or voice notes); the bot manages client document collection and sends emails on the broker's behalf.

## Stack
- Rails 7.2 + PostgreSQL
- Sidekiq + Redis for background jobs
- OpenAI API: Whisper (speech-to-text) + GPT-4o (agent)
- Meta WhatsApp Business API for messaging
- ActionMailer (SMTP) for email

## Architecture

```
WhatsApp webhook
  └─ Webhooks::WhatsappController
       └─ ProcessInboundMessageJob (Sidekiq)
            ├─ audio → Openai::TranscriptionService (Whisper)
            ├─ text/transcript → Agent::PropertyBrokerService (GPT-4o + tools)
            │    ├─ tool: send_email → BrokerMailer
            │    ├─ tool: update_document_status → Conversation#context (jsonb)
            │    └─ tool: get_client_status → Conversation#context
            └─ Whatsapp::Client (send reply)
```

## Key models
- `Conversation` — one per WhatsApp number, stores `context` jsonb (client document state)
- `Message` — full message history, role = user|assistant

## Environment variables (see .env.example)
- `OPENAI_API_KEY` — for Whisper + GPT-4o
- `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_VERIFY_TOKEN`, `WHATSAPP_APP_SECRET`
- `BROKER_EMAIL_FROM`, `SMTP_*`
- `REDIS_URL`

## Running locally
```bash
bundle install
rails db:create db:migrate
bundle exec sidekiq          # background jobs
rails server                 # web server
```

## Webhook setup (Meta)
1. Deploy app to public URL
2. In Meta developer dashboard → WhatsApp → Configuration
3. Webhook URL: `https://yourdomain.com/webhooks/whatsapp`
4. Verify token: value of `WHATSAPP_VERIFY_TOKEN`
5. Subscribe to `messages` field
