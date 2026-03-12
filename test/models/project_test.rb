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

  # Test 32
  test "recompute_totals! calculates total_exVAT correctly" do
    @project.save!
    room = Room.create!(project: @project, name: "Salon")
    category = WorkCategory.create!(name: "Peinture", slug: "peinture-pt")
    material = Material.create!(work_category: category, unit: "L", public_price_exVAT: 10, vat_rate: 10)
    WorkItem.create!(room: room, work_category: category, material: material,
                     label: "Peinture murs", quantity: 5, unit: "L", unit_price_exVAT: 20.0, vat_rate: 10)
    @project.reload
    assert_equal 100.0, @project.total_exVAT
  end

  # Test 33
  test "recompute_totals! calculates total_incVAT correctly" do
    @project.save!
    room = Room.create!(project: @project, name: "Cuisine")
    category = WorkCategory.create!(name: "Carrelage", slug: "carrelage-pt")
    material = Material.create!(work_category: category, unit: "m²", public_price_exVAT: 10, vat_rate: 20)
    WorkItem.create!(room: room, work_category: category, material: material,
                     label: "Carrelage sol", quantity: 4, unit: "m²", unit_price_exVAT: 50.0, vat_rate: 20)
    @project.reload
    assert_equal 240.0, @project.total_incVAT
  end

  # Test 34
  test "recompute_totals! sets both totals to zero when no work items exist" do
    @project.save!
    @project.recompute_totals!
    assert_equal 0, @project.total_exVAT
    assert_equal 0, @project.total_incVAT
  end

  # Test 35
  test "status defaults to draft" do
    project = Project.create!(user: @user)
    assert project.draft?
  end

  # Test 36
  test "destroying project destroys its documents" do
    @project.save!
    Document.create!(project: @project, file_name: "quote.pdf", file_url: "https://example.com/quote.pdf")
    assert_difference "Document.count", -1 do
      @project.destroy
    end
  end
end
