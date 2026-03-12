module TurnstileManagement
  # ver 1.0.1

  require "net/http"

  def verify_turnstile(token)
    return true unless Rails.env.production?
    uri = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")
    res = Net::HTTP.post_form(uri, {
      "secret" => ENV.fetch("CLOUDFLARE_TURNSTILE_SECRET_KEY"),
      "response" => token,
      "remoteip" => request.remote_ip
    })
    result = JSON.parse(res.body)
    result["success"] == true
  end
end
