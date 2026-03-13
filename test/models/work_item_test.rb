require "test_helper"

class WorkItemTest < ActiveSupport::TestCase
  def setup
    @user     = User.create!(email: "wi@test.com", password: "password123")
    @project  = Project.create!(user: @user, status: "in_progress")
    @room     = Room.create!(project: @project, name: "Salon")
    @category = WorkCategory.create!(name: "Peinture", slug: "peinture-wi")
    @material = Material.create!(work_category: @category, unit: "L", public_price_exVAT: 18.50, vat_rate: 10)
    @work_item = WorkItem.new(
      room: @room,
      work_category: @category,
      material: @material,
      label: "Peinture plafond",
      quantity: 3,
      unit: "L",
      unit_price_exVAT: 18.50,
      vat_rate: 10,
      standing_level: 1
    )
  end

  test "valid work_item saves successfully" do
    assert @work_item.valid?
    assert @work_item.save
  end

  test "belongs to room" do
    @work_item.save!
    assert_equal @room, @work_item.room
  end

  test "belongs to work_category" do
    @work_item.save!
    assert_equal @category, @work_item.work_category
  end

  test "belongs to material" do
    @work_item.save!
    assert_equal @material, @work_item.material
  end

  test "requires room" do
    @work_item.room = nil
    assert_not @work_item.valid?
  end

  test "requires work_category" do
    @work_item.work_category = nil
    assert_not @work_item.valid?
  end

  test "requires material" do
    @work_item.material = nil
    assert_not @work_item.valid?
  end

  # Test 37
  test "requires label" do
    @work_item.label = nil
    assert_not @work_item.valid?
    assert_includes @work_item.errors[:label], "can't be blank"
  end

  # Test 38
  test "quantity must be greater than zero" do
    @work_item.quantity = 0
    assert_not @work_item.valid?
    @work_item.quantity = -1
    assert_not @work_item.valid?
  end

  # Test 39
  test "unit_price_exVAT can be zero" do
    @work_item.unit_price_exVAT = 0
    assert @work_item.valid?
  end

  # Test 40
  test "unit_price_exVAT cannot be negative" do
    @work_item.unit_price_exVAT = -5
    assert_not @work_item.valid?
  end

  # Test 41
  test "saving a work_item triggers recompute_totals! on its project" do
    @work_item.save!
    @room.project.reload
    expected_exvat = @work_item.quantity * @work_item.unit_price_exVAT
    assert_equal expected_exvat, @room.project.total_exVAT
  end
end
