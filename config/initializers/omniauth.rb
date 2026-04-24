Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV["GOOGLE_CLIENT_ID"],
    ENV["GOOGLE_CLIENT_SECRET"],
    scope: %w[
      email
      profile
      https://www.googleapis.com/auth/gmail.modify
      https://www.googleapis.com/auth/drive.readonly
    ].join(","),
    access_type: "offline",
    prompt:      "consent",
    include_granted_scopes: true
end

OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.silence_get_warning     = true

# When behind a reverse proxy (ngrok, load balancer), build the redirect_uri
# from forwarded headers so it matches what Google has registered.
OmniAuth.config.full_host = lambda { |env|
  scheme = env["HTTP_X_FORWARDED_PROTO"] || env["rack.url_scheme"]
  host   = env["HTTP_X_FORWARDED_HOST"]  || env["HTTP_HOST"]
  "#{scheme}://#{host}"
}
