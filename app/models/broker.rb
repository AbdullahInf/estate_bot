class Broker < ApplicationRecord
  has_many :inbound_emails, dependent: :destroy

  validates :email,      presence: true, uniqueness: { case_sensitive: false }
  validates :google_uid, presence: true, uniqueness: true

  def self.from_omniauth(auth)
    find_or_initialize_by(google_uid: auth.uid).tap do |broker|
      broker.email                   = auth.info.email
      broker.name                    = auth.info.name
      broker.google_access_token     = auth.credentials.token
      # Google only returns a refresh_token on the first authorization;
      # keep the existing one if the new response omits it.
      broker.google_refresh_token    = auth.credentials.refresh_token if auth.credentials.refresh_token.present?
      broker.google_token_expires_at = Time.at(auth.credentials.expires_at)
      broker.save!
    end
  end

  def fresh_access_token
    refresh_google_token! if token_expired?
    google_access_token
  end

  private

  def token_expired?
    google_token_expires_at.nil? || google_token_expires_at < 5.minutes.from_now
  end

  def refresh_google_token!
    response = Faraday.post("https://oauth2.googleapis.com/token") do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form(
        client_id:     ENV["GOOGLE_CLIENT_ID"],
        client_secret: ENV["GOOGLE_CLIENT_SECRET"],
        refresh_token: google_refresh_token,
        grant_type:    "refresh_token"
      )
    end

    data = JSON.parse(response.body)
    raise "Token refresh failed: #{data['error_description']}" if data["error"].present?

    update!(
      google_access_token:     data["access_token"],
      google_token_expires_at: Time.current + data["expires_in"].seconds
    )
  end
end
