require "test_helper"
require "ostruct"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.new(email: "test@example.com", password: "password123")
  end

  test "valid user saves successfully" do
    assert @user.valid?
    assert @user.save
  end

  test "requires email" do
    @user.email = nil
    assert_not @user.valid?
  end

  test "requires password" do
    @user.password = nil
    assert_not @user.valid?
  end

  test "email must be unique" do
    @user.save!
    duplicate = User.new(email: "test@example.com", password: "password123")
    assert_not duplicate.valid?
  end

  test "has many projects" do
    assert_respond_to @user, :projects
  end

  # Google OAuth
  test "from_omniauth creates a new user when none exists" do
    auth = OpenStruct.new(
      provider: "google_oauth2",
      uid: "123456789",
      info: OpenStruct.new(email: "google@example.com")
    )
    assert_difference "User.count", 1 do
      user = User.from_omniauth(auth)
      assert user.persisted?
      assert_equal "google@example.com", user.email
      assert_equal "google_oauth2", user.provider
      assert_equal "123456789", user.uid
    end
  end

  test "from_omniauth returns existing user on subsequent calls" do
    auth = OpenStruct.new(
      provider: "google_oauth2",
      uid: "987654321",
      info: OpenStruct.new(email: "existing@example.com")
    )
    User.from_omniauth(auth)
    assert_no_difference "User.count" do
      user = User.from_omniauth(auth)
      assert user.persisted?
    end
  end
end
