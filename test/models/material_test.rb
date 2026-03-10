require "test_helper"

class MaterialTest < ActiveSupport::TestCase
  def setup
    @category = WorkCategory.create!(name: "Peinture", slug: "peinture")
    @material = Material.new(
      work_category: @category,
      brand: "Dulux",
      reference: "REF-001",
      unit: "L",
      public_price_exVAT: 18.50,
      vat_rate: 10
    )
  end

  test "valid material saves successfully" do
    assert @material.valid?
    assert @material.save
  end

  test "requires unit" do
    @material.unit = nil
    assert_not @material.valid?
    assert_includes @material.errors[:unit], "can't be blank"
  end

  test "requires public_price_exVAT" do
    @material.public_price_exVAT = nil
    assert_not @material.valid?
    assert_includes @material.errors[:public_price_exVAT], "can't be blank"
  end

  test "public_price_exVAT must be non-negative" do
    @material.public_price_exVAT = -1
    assert_not @material.valid?
  end

  test "vat_rate must be an integer" do
    @material.vat_rate = 10.5
    assert_not @material.valid?
  end

  test "belongs to a work_category" do
    @material.save!
    assert_equal @category, @material.work_category
  end

  test "has many work_items" do
    assert_respond_to @material, :work_items
  end
end
