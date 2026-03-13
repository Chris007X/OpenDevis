require "test_helper"

class ProjectPolicyTest < ActiveSupport::TestCase
  def setup
    @owner = User.create!(email: "owner@policy.com", password: "password123")
    @other = User.create!(email: "other@policy.com", password: "password123")
    @project = Project.create!(user: @owner, status: "in_progress")
  end

  # Test 47
  test "owner can show their own project" do
    policy = ProjectPolicy.new(@owner, @project)
    assert policy.show?
  end

  # Test 48
  test "other user cannot show a project they do not own" do
    policy = ProjectPolicy.new(@other, @project)
    assert_not policy.show?
  end

  # Test 49
  test "owner can destroy their own project" do
    policy = ProjectPolicy.new(@owner, @project)
    assert policy.destroy?
  end

  # Test 50
  test "scope returns only projects belonging to the current user" do
    other_project = Project.create!(user: @other, status: "in_progress")
    scope = ProjectPolicy::Scope.new(@owner, Project).resolve
    assert_includes scope, @project
    assert_not_includes scope, other_project
  end
end
