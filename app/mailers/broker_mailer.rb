class BrokerMailer < ApplicationMailer
  def generic(to:, subject:, body:, cc: nil, attachment: nil)
    @body = body

    if attachment
      attachments[attachment[:filename]] = {
        mime_type: attachment[:mime_type],
        content:   attachment[:data]
      }
    end

    mail_opts = {
      to:      to,
      subject: subject,
      from:    ENV.fetch("BROKER_EMAIL_FROM", "broker@estatebot.com")
    }
    mail_opts[:cc] = cc if cc.present?

    mail(mail_opts)
  end
end
