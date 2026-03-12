require "test_helper"

class ArtisanTest < ActiveSupport::TestCase
  def setup
    @artisan = Artisan.new(
      name: "Jean Dupont",
      email: "jean@artisan.com",
      password: "password123",
      postcode: "75001",
      active: true
    )
  end

  # Test 5
  test "valid artisan saves successfully" do
    assert @artisan.valid?
    assert @artisan.save
  end

  # Test 6
  test "requires name" do
    @artisan.name = nil
    assert_not @artisan.valid?
    assert_includes @artisan.errors[:name], "can't be blank"
  end

  # Test 7
  test "requires postcode" do
    @artisan.postcode = nil
    assert_not @artisan.valid?
    assert_includes @artisan.errors[:postcode], "can't be blank"
  end

  # Test 8
  test "rating must be between 0 and 5" do
    @artisan.rating = 6
    assert_not @artisan.valid?
    @artisan.rating = -1
    assert_not @artisan.valid?
  end

  # Test 9
  test "rating can be nil" do
    @artisan.rating = nil
    assert @artisan.valid?
  end

  # Test 10
  test "star_rating returns 0 when rating is nil" do
    @artisan.rating = nil
    assert_equal 0, @artisan.star_rating
  end

  # Test 11
  test "star_rating rounds to one decimal place" do
    @artisan.rating = 4.567
    assert_equal 4.6, @artisan.star_rating
  end
end
