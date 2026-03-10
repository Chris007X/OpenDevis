require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "project@test.com", password: "password123")
    @project = Project.new(user: @user, status: "draft")
  end

  test "valid project saves successfully" do
    assert @project.valid?
    assert @project.save
  end

  test "belongs to a user" do
    @project.save!
    assert_equal @user, @project.user
  end

  test "has many rooms" do
    assert_respond_to @project, :rooms
  end

  test "has many work_items through rooms" do
    assert_respond_to @project, :work_items
  end

  test "destroying project destroys its rooms" do
    @project.save!
    Room.create!(project: @project, name: "Cuisine")
    assert_difference "Room.count", -1 do
      @project.destroy
    end
  end
end
