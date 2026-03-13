require "test_helper"

class BiddingRequestTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "bireq@test.com", password: "password123")
    @project = Project.create!(user: @user, status: "in_progress")
    @bidding_round = BiddingRound.create!(project: @project, standing_level: 2, status: "draft", deadline: 7.days.from_now)
    @category = WorkCategory.create!(name: "Électricité", slug: "electricite-req")
    @artisan = Artisan.create!(name: "Paul Martin", email: "paul@test.com", password: "password123", postcode: "69001")
    @bidding_request = BiddingRequest.new(
      bidding_round: @bidding_round,
      work_category: @category,
      artisan: @artisan,
      status: "pending"
    )
  end

  # Test 20
  test "auto-generates a token on create" do
    @bidding_request.save!
    assert_not_nil @bidding_request.token
    assert_operator @bidding_request.token.length, :>, 10
  end

  # Test 21
  test "token must be unique" do
    @bidding_request.save!
    artisan2 = Artisan.create!(name: "Marc", email: "marc@test.com", password: "password123", postcode: "69001")
    dup = BiddingRequest.new(
      bidding_round: @bidding_round, work_category: @category,
      artisan: artisan2, status: "pending"
    )
    dup.save!
    dup.token = @bidding_request.token
    assert_not dup.valid?
    assert_includes dup.errors[:token], "has already been taken"
  end

  # Test 22
  test "artisan must be unique per bidding_round and work_category" do
    @bidding_request.save!
    duplicate = BiddingRequest.new(
      bidding_round: @bidding_round, work_category: @category,
      artisan: @artisan, status: "pending"
    )
    assert_not duplicate.valid?
  end

  # Test 23
  test "responded? returns true when status is responded" do
    @bidding_request.status = "responded"
    assert @bidding_request.responded?
    @bidding_request.status = "pending"
    assert_not @bidding_request.responded?
  end

  # Test 24
  test "declined? returns true when status is declined" do
    @bidding_request.status = "declined"
    assert @bidding_request.declined?
    @bidding_request.status = "sent"
    assert_not @bidding_request.declined?
  end

  # Test 25
  test "awaiting? returns true for pending and sent statuses" do
    @bidding_request.status = "pending"
    assert @bidding_request.awaiting?
    @bidding_request.status = "sent"
    assert @bidding_request.awaiting?
    @bidding_request.status = "responded"
    assert_not @bidding_request.awaiting?
  end

  # Test 26
  test "terminal? returns true for responded, declined, expired, and replaced" do
    %w[responded declined expired replaced].each do |status|
      @bidding_request.status = status
      assert @bidding_request.terminal?, "Expected terminal? to be true for status '#{status}'"
    end
    @bidding_request.status = "pending"
    assert_not @bidding_request.terminal?
  end
end
