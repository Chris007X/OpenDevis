require "test_helper"

class RoomTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "user@test.com", password: "password123")
    @project = Project.create!(user: @user, status: "draft")
    @room = Room.new(project: @project, name: "Salon", surface_sqm: 20.0, perimeter_lm: 18.0, wall_height_m: 2.5)
  end

  test "valid room saves successfully" do
    assert @room.valid?
    assert @room.save
  end

  test "requires name" do
    @room.name = nil
    assert_not @room.valid?
    assert_includes @room.errors[:name], "can't be blank"
  end

  test "surface_sqm must be positive" do
    @room.surface_sqm = 0
    assert_not @room.valid?
  end

  test "perimeter_lm must be positive" do
    @room.perimeter_lm = -5
    assert_not @room.valid?
  end

  test "wall_height_m must be positive" do
    @room.wall_height_m = -1
    assert_not @room.valid?
  end

  test "nil dimensions are allowed" do
    @room.surface_sqm = nil
    @room.perimeter_lm = nil
    @room.wall_height_m = nil
    assert @room.valid?
  end

  test "belongs to a project" do
    @room.save!
    assert_equal @project, @room.project
  end

  test "has many work_items" do
    assert_respond_to @room, :work_items
  end

  test "destroying room destroys its work_items" do
    @room.save!
    category = WorkCategory.create!(name: "Peinture", slug: "peinture-room-test")
    material = Material.create!(work_category: category, unit: "L", public_price_exVAT: 10, vat_rate: 10)
    WorkItem.create!(room: @room, work_category: category, material: material, label: "Test item", quantity: 1, unit: "L", unit_price_exVAT: 10, vat_rate: 10)
    assert_difference "WorkItem.count", -1 do
      @room.destroy
    end
  end
end
