require "test_helper"

class WorkCategoryTest < ActiveSupport::TestCase
  test "valid work_category saves successfully" do
    category = WorkCategory.new(name: "Carrelage", slug: "carrelage")
    assert category.valid?
    assert category.save
  end

  test "requires a slug" do
    category = WorkCategory.new(name: "Menuiserie")
    assert_not category.save
    assert_includes category.errors[:slug], "can't be blank"
  end

  # Test 42
  test "name must be at least 2 characters" do
    category = WorkCategory.new(name: "A", slug: "a")
    assert_not category.valid?
    assert_not_empty category.errors[:name]
  end

  # Test 43
  test "slug must be unique" do
    WorkCategory.create!(name: "Isolation", slug: "isolation-dup")
    duplicate = WorkCategory.new(name: "Isolation 2", slug: "isolation-dup")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  # Test 44
  test "slug is automatically lowercased before validation" do
    category = WorkCategory.new(name: "Maçonnerie", slug: "MACONNERIE")
    category.valid?
    assert_equal "maconnerie", category.slug
  end

  # Test 45
  test "slug with invalid characters (spaces, uppercase after auto-downcase) is rejected" do
    category = WorkCategory.new(name: "Test Category", slug: "invalid slug!")
    assert_not category.valid?
    assert_not_empty category.errors[:slug]
  end

  # Test 46
  test "has many materials" do
    assert_respond_to WorkCategory.new, :materials
  end
end
