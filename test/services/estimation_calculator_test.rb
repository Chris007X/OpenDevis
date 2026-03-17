require "test_helper"

class EstimationCalculatorTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "calc-test@example.com", password: "password123", password_confirmation: "password123")
    @project = @user.projects.create!(
      location_zip: "75011",
      total_surface_sqm: 50.0,
      status: :in_progress
    )

    # Ensure required work categories exist
    @cat_peintures = WorkCategory.find_or_create_by!(slug: "peintures") { |c| c.name = "Peintures" }
    @cat_electricite = WorkCategory.find_or_create_by!(slug: "electricite") { |c| c.name = "Électricité" }
    @cat_sdb = WorkCategory.find_or_create_by!(slug: "salle_de_bain_wc") { |c| c.name = "Salle de bain & WC" }

    # Seed minimal reference prices for testing (v2: Standard prices, no standing_level)
    ReferencePrice.where(category_slug: %w[peintures electricite salle_de_bain_wc]).delete_all

    # Peintures — Standard base prices (Éco/Premium derived via coefficients)
    ReferencePrice.create!(category_slug: "peintures", label: "Préparation murs (enduit + ponçage) + 2 couches", unit: "m2",
      supply_price_exVAT: 4.00, labor_price_exVAT: 18.00, vat_rate: 10,
      quantity_formula: "wall_surface", sort_order: 0)
    ReferencePrice.create!(category_slug: "peintures", label: "Peinture plafond 2 couches blanc mat", unit: "m2",
      supply_price_exVAT: 3.00, labor_price_exVAT: 16.00, vat_rate: 10,
      quantity_formula: "ceiling", sort_order: 1)
    ReferencePrice.create!(category_slug: "peintures", label: "Peinture boiseries (portes, plinthes) laque", unit: "ml",
      supply_price_exVAT: 3.00, labor_price_exVAT: 12.00, vat_rate: 10,
      quantity_formula: "perimeter", sort_order: 2)

    # Electricité
    ReferencePrice.create!(category_slug: "electricite", label: "Tableau électrique NF C 15-100 complet", unit: "pce",
      supply_price_exVAT: 350.00, labor_price_exVAT: 400.00, vat_rate: 10,
      quantity_formula: "fixed:1", sort_order: 0)
    ReferencePrice.create!(category_slug: "electricite", label: "Prises + interrupteurs encastrés", unit: "pce",
      supply_price_exVAT: 12.00, labor_price_exVAT: 35.00, vat_rate: 10,
      quantity_formula: "per_sqm:0.4", sort_order: 1)

    # SDB — room-restricted item
    ReferencePrice.create!(category_slug: "salle_de_bain_wc", label: "Douche italienne receveur extra-plat", unit: "pce",
      supply_price_exVAT: 500.00, labor_price_exVAT: 500.00, vat_rate: 10,
      quantity_formula: "fixed:1", applicable_rooms: "SDB", sort_order: 0)

    @calculator = EstimationCalculator.new(@project)
  end

  # ── geo_coefficient_for ──────────────────────────────────────────────────

  test "geo_coefficient_for returns 1.25 for Paris" do
    assert_equal 1.25, @calculator.geo_coefficient_for("75011")
  end

  test "geo_coefficient_for handles parenthesized format" do
    assert_equal 1.25, @calculator.geo_coefficient_for("Paris (75011)")
  end

  test "geo_coefficient_for returns 1.10 for Lyon" do
    assert_equal 1.10, @calculator.geo_coefficient_for("69003")
  end

  test "geo_coefficient_for returns 1.00 for unknown department" do
    assert_equal 1.00, @calculator.geo_coefficient_for("26000")
  end

  test "geo_coefficient_for returns 1.00 for nil" do
    assert_equal 1.00, @calculator.geo_coefficient_for(nil)
  end

  # ── generate! — whole project mode ───────────────────────────────────────

  test "generate! creates single room 'Ensemble des travaux' for whole-project mode" do
    @calculator.generate!(category_slugs: ["peintures"], standing_levels: [2])

    assert_equal 1, @project.rooms.count
    assert_equal "Ensemble des travaux", @project.rooms.first.name
    assert @project.rooms.first.work_items.any?
  end

  test "generate! creates multiple rooms for par_piece mode" do
    rooms_data = [
      { "name" => "Salon", "base" => "Salon", "surface" => "25" },
      { "name" => "Chambre", "base" => "Chambre", "surface" => "14" }
    ]

    @calculator.generate!(
      category_slugs: ["peintures"],
      standing_levels: [2],
      rooms_data: rooms_data,
      room_categories: { "Salon" => ["peintures"], "Chambre" => ["peintures"] },
      renovation_type: "par_piece"
    )

    assert_equal 2, @project.rooms.count
    assert_equal %w[Salon Chambre], @project.rooms.order(:id).map(&:name)
  end

  test "generate! clears existing rooms before regenerating" do
    @project.rooms.create!(name: "Old room")

    @calculator.generate!(category_slugs: ["peintures"], standing_levels: [2])

    assert_equal 1, @project.rooms.count
    assert_equal "Ensemble des travaux", @project.rooms.first.name
  end

  # ── Standing coefficients + geo ──────────────────────────────────────────

  test "standing coefficients apply correctly — Éco uses supply×0.75 + labor×0.90×geo" do
    # Peinture murs: supply=4.00, labor=18.00, Paris geo=1.25
    # Éco: supply×0.75 + labor×0.90×1.25 = 3.00 + 20.25 = 23.25
    @calculator.generate!(category_slugs: ["peintures"], standing_levels: [1])

    wi = @project.rooms.first.work_items.find_by(label: "Préparation murs (enduit + ponçage) + 2 couches")
    assert_not_nil wi
    assert_equal 23.25, wi.unit_price_exVAT.to_f
  end

  test "standing coefficients apply correctly — Standard uses supply×1 + labor×1×geo" do
    # Peinture murs: supply=4.00, labor=18.00, Paris geo=1.25
    # Standard: 4.00 + 18.00×1.25 = 26.50
    @calculator.generate!(category_slugs: ["peintures"], standing_levels: [2])

    wi = @project.rooms.first.work_items.find_by(label: "Préparation murs (enduit + ponçage) + 2 couches")
    assert_not_nil wi
    assert_equal 26.50, wi.unit_price_exVAT.to_f
  end

  test "standing coefficients apply correctly — Premium uses supply×1.35 + labor×1.15×geo" do
    # Peinture murs: supply=4.00, labor=18.00, Paris geo=1.25
    # Premium: 4.00×1.35 + 18.00×1.15×1.25 = 5.40 + 25.875 = 31.275 → rounded 31.28
    @calculator.generate!(category_slugs: ["peintures"], standing_levels: [3])

    wi = @project.rooms.first.work_items.find_by(label: "Préparation murs (enduit + ponçage) + 2 couches")
    assert_not_nil wi
    assert_equal 31.28, wi.unit_price_exVAT.to_f
  end

  # ── estimate (preview without persisting) ────────────────────────────────

  test "estimate returns eco/standard/premium totals without persisting" do
    result = @calculator.estimate(category_slugs: ["peintures"])

    assert result[:eco] > 0
    assert result[:standard] > 0
    assert result[:premium] > 0
    assert result[:eco] < result[:standard]
    assert result[:standard] < result[:premium]
    assert_equal 0, @project.rooms.count, "estimate should not create rooms"
  end

  # ── ReferencePrice#compute_quantity ──────────────────────────────────────

  test "compute_quantity surface formula uses room_surface" do
    ref = ReferencePrice.new(quantity_formula: "surface")
    assert_equal 25.0, ref.compute_quantity(room_surface: 25.0)
  end

  test "compute_quantity wall_surface formula uses perimeter × height" do
    ref = ReferencePrice.new(quantity_formula: "wall_surface")
    assert_equal 50.0, ref.compute_quantity(room_perimeter: 20.0, wall_height: 2.5)
  end

  test "compute_quantity fixed:N returns N" do
    ref = ReferencePrice.new(quantity_formula: "fixed:3")
    assert_equal 3.0, ref.compute_quantity
  end

  test "compute_quantity per_sqm:N multiplies surface and ceils" do
    ref = ReferencePrice.new(quantity_formula: "per_sqm:0.3")
    # 50.0 * 0.3 = 15.0 → ceil = 15
    assert_equal 15, ref.compute_quantity(room_surface: 50.0)
  end

  test "compute_quantity per_lm:N multiplies perimeter and ceils" do
    ref = ReferencePrice.new(quantity_formula: "per_lm:0.5")
    # 20.0 * 0.5 = 10.0 → ceil = 10
    assert_equal 10, ref.compute_quantity(room_perimeter: 20.0)
  end

  # ── ReferencePrice#unit_price_for ──────────────────────────────────────

  test "unit_price_for without geo returns standing-adjusted price" do
    ref = ReferencePrice.new(supply_price_exVAT: 4.00, labor_price_exVAT: 18.00)
    # Éco: 4×0.75 + 18×0.90 = 3.00 + 16.20 = 19.20
    assert_equal 19.20, ref.unit_price_for(standing_level: 1)
    # Standard: 4 + 18 = 22.00
    assert_equal 22.00, ref.unit_price_for(standing_level: 2)
    # Premium: 4×1.35 + 18×1.15 = 5.40 + 20.70 = 26.10
    assert_equal 26.10, ref.unit_price_for(standing_level: 3)
  end

  # ── Room-restricted items ────────────────────────────────────────────────

  test "room-restricted items are not generated for non-matching rooms" do
    rooms_data = [{ "name" => "Salon", "base" => "Salon", "surface" => "25" }]

    @calculator.generate!(
      category_slugs: ["salle_de_bain_wc"],
      standing_levels: [1],
      rooms_data: rooms_data,
      room_categories: { "Salon" => ["salle_de_bain_wc"] },
      renovation_type: "par_piece"
    )

    room = @project.rooms.first
    assert_equal 0, room.work_items.count
  end

  test "room-restricted items are generated for matching rooms" do
    rooms_data = [{ "name" => "SDB", "base" => "SDB", "surface" => "6" }]

    @calculator.generate!(
      category_slugs: ["salle_de_bain_wc"],
      standing_levels: [1],
      rooms_data: rooms_data,
      room_categories: { "SDB" => ["salle_de_bain_wc"] },
      renovation_type: "par_piece"
    )

    room = @project.rooms.first
    assert room.work_items.any?, "SDB-restricted items should appear in SDB room"
  end
end
