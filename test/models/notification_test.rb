require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "notif@test.com", password: "password123")
    @notification = Notification.new(
      user: @user,
      kind: "artisan_responded",
      title: "Un artisan a répondu",
      read: false
    )
  end

  # Test 27
  test "valid notification saves successfully" do
    assert @notification.valid?
    assert @notification.save
  end

  # Test 28
  test "requires kind" do
    @notification.kind = nil
    assert_not @notification.valid?
    assert_includes @notification.errors[:kind], "can't be blank"
  end

  # Test 29
  test "kind must be one of the defined KINDS" do
    @notification.kind = "unknown_kind"
    assert_not @notification.valid?
    assert_not_empty @notification.errors[:kind]
  end

  # Test 30
  test "requires title" do
    @notification.title = nil
    assert_not @notification.valid?
    assert_includes @notification.errors[:title], "can't be blank"
  end

  # Test 31
  test "unread scope returns only unread notifications" do
    @notification.save!
    read_notif = Notification.create!(user: @user, kind: "all_responded", title: "Tous ont répondu", read: true)
    unread_ids = Notification.unread.pluck(:id)
    assert_includes unread_ids, @notification.id
    assert_not_includes unread_ids, read_notif.id
  end
end
