require "test_helper"

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
end
