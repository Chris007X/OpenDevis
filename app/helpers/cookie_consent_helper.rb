module CookieConsentHelper
  def cookies_accepted?(category)
    raw = cookies[:cookie_consent]
    return false if raw.blank?

    consent = JSON.parse(CGI.unescape(raw))
    consent[category.to_s] == true
  rescue JSON::ParserError
    false
  end
end
