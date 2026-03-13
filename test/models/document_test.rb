require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "doc@test.com", password: "password123")
    @project = Project.create!(user: @user, status: "in_progress")
    @document = Document.new(project: @project, file_name: "devis.pdf", file_url: "https://example.com/devis.pdf")
  end

  # Test 1
  test "valid document saves successfully" do
    assert @document.valid?
    assert @document.save
  end

  # Test 2
  test "requires file_name" do
    @document.file_name = nil
    assert_not @document.valid?
    assert_includes @document.errors[:file_name], "can't be blank"
  end

  # Test 3
  test "requires file_url" do
    @document.file_url = nil
    assert_not @document.valid?
    assert_includes @document.errors[:file_url], "can't be blank"
  end

  # Test 4
  test "belongs to a project" do
    @document.save!
    assert_equal @project, @document.project
  end
end
