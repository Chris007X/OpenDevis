require "test_helper"

class BiddingRoundTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "bidding@test.com", password: "password123")
    @project = Project.create!(user: @user, status: "in_progress")
    @bidding_round = BiddingRound.new(
      project: @project,
      standing_level: 2,
      status: "draft",
      deadline: 7.days.from_now
    )
  end

  # Test 12
  test "valid bidding_round saves successfully" do
    assert @bidding_round.valid?
    assert @bidding_round.save
  end

  # Test 13
  test "standing_level must be 1, 2, or 3" do
    @bidding_round.standing_level = 4
    assert_not @bidding_round.valid?
    @bidding_round.standing_level = 0
    assert_not @bidding_round.valid?
  end

  # Test 14
  test "status must be one of the allowed values" do
    @bidding_round.status = "invalid_status"
    assert_not @bidding_round.valid?
  end

  # Test 15
  test "requires deadline" do
    @bidding_round.deadline = nil
    assert_not @bidding_round.valid?
    assert_includes @bidding_round.errors[:deadline], "can't be blank"
  end

  # Test 16
  test "project_id must be unique" do
    @bidding_round.save!
    duplicate = BiddingRound.new(
      project: @project,
      standing_level: 1,
      status: "draft",
      deadline: 3.days.from_now
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:project_id], "has already been taken"
  end

  # Test 17
  test "standing_label returns correct label for each level" do
    @bidding_round.standing_level = 1
    assert_equal "Éco", @bidding_round.standing_label
    @bidding_round.standing_level = 2
    assert_equal "Standard", @bidding_round.standing_label
    @bidding_round.standing_level = 3
    assert_equal "Premium", @bidding_round.standing_label
  end

  # Test 18
  test "responses_received counts only responded requests" do
    @bidding_round.save!
    category = WorkCategory.create!(name: "Plomberie", slug: "plomberie-br")
    artisan1 = Artisan.create!(name: "A1", email: "a1@test.com", password: "pw123456", postcode: "75001")
    artisan2 = Artisan.create!(name: "A2", email: "a2@test.com", password: "pw123456", postcode: "75001")
    BiddingRequest.create!(bidding_round: @bidding_round, work_category: category, artisan: artisan1, status: "responded")
    BiddingRequest.create!(bidding_round: @bidding_round, work_category: category, artisan: artisan2, status: "pending")
    assert_equal 1, @bidding_round.responses_received
  end

  # Test 19
  test "deadline_passed? returns true when deadline is in the past" do
    @bidding_round.deadline = 1.day.ago
    assert @bidding_round.deadline_passed?
  end
end
