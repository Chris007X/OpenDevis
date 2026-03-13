require "test_helper"

class Users::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  def set_oauth_mock(email:, uid:)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email }
    )
  end

  test "successful google sign-in creates a new user and redirects" do
    set_oauth_mock(email: "newuser@example.com", uid: "new_uid_111")
    assert_difference "User.count", 1 do
      get "/users/auth/google_oauth2/callback"
    end
    assert_response :redirect
  end

  test "successful google sign-in for existing user does not create a new user" do
    set_oauth_mock(email: "existing_oauth@example.com", uid: "existing_uid_222")
    User.create!(
      email: "existing_oauth@example.com",
      provider: "google_oauth2",
      uid: "existing_uid_222",
      password: Devise.friendly_token[0, 20]
    )
    assert_no_difference "User.count" do
      get "/users/auth/google_oauth2/callback"
    end
    assert_response :redirect
  end
end
