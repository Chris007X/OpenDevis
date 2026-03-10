require "test_helper"

class WorkCategoryTest < ActiveSupport::TestCase
  test "valid work_category saves successfully" do
    category = WorkCategory.new(name: "Carrelage", slug: "carrelage")
    assert category.valid?
    assert category.save
  end

  test "can be created without slug" do
    category = WorkCategory.new(name: "Menuiserie")
    assert category.save
  end
end
