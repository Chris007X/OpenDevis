class EstimationCalculator
  GEO_COEFFICIENTS = {
    "75" => 1.25, "92" => 1.22, "94" => 1.18, "93" => 1.15,
    "78" => 1.15, "91" => 1.12, "95" => 1.12, "77" => 1.08,
    "69" => 1.10, "13" => 1.08, "06" => 1.15, "33" => 1.06,
    "31" => 1.06, "44" => 1.05, "59" => 1.04, "67" => 1.06,
    "34" => 1.05, "35" => 1.04
  }.freeze
  GEO_DEFAULT = 1.00

  CATEGORY_SLUG_MAPPING = {
    "demolition_maconnerie"   => "maconnerie",
    "fenetres"                => "menuiserie",
    "toiture"                 => "isolation",
    "ventilation_chauffage"   => "chauffage",
    "menuiseries_interieures" => "menuiserie",
    "peintures"               => "peinture",
    "cuisine"                 => "plomberie",
    "salle_de_bain_wc"        => "plomberie"
  }.freeze

  def initialize(project)
    @project = project
  end

  # Persist work items to DB
  def generate!(category_slugs:, standing_levels: [1, 2, 3], room_categories: {}, rooms_data: [], renovation_type: "renovation_complete")
    @project.rooms.destroy_all

    geo = geo_coefficient_for(@project.location_zip)
    project_surface = @project.total_surface_sqm

    if renovation_type == "par_piece" && rooms_data.present?
      rooms_data.each do |room_data|
        name    = room_data["name"]
        base    = room_data["base"] || name
        surface = room_data["surface"].presence&.to_f

        room_attrs = { name: name }
        room_attrs[:surface_sqm] = surface if surface && surface > 0
        room = @project.rooms.create!(**room_attrs)

        cats = room_categories[base] || room_categories[name] || category_slugs
        perimeter = estimate_perimeter(surface)

        standing_levels.each do |level|
          generate_items_for_room(room, cats, level, geo,
            room_surface: surface, room_perimeter: perimeter,
            project_surface: project_surface, room_base_name: base)
        end
      end
    else
      room = @project.rooms.create!(name: "Ensemble des travaux")
      standing_levels.each do |level|
        generate_items_for_room(room, category_slugs, level, geo,
          room_surface: project_surface, room_perimeter: estimate_perimeter(project_surface),
          project_surface: project_surface, room_base_name: nil)
      end
    end

    @project.recompute_totals!
  end

  # Preview without persisting (returns hash with :eco, :standard, :premium totals)
  def estimate(category_slugs:, room_categories: {}, rooms_data: [], renovation_type: "renovation_complete")
    geo = geo_coefficient_for(@project.location_zip)
    project_surface = @project.total_surface_sqm
    totals = { eco: 0.0, standard: 0.0, premium: 0.0 }
    level_keys = { 1 => :eco, 2 => :standard, 3 => :premium }

    if renovation_type == "par_piece" && rooms_data.present?
      rooms_data.each do |room_data|
        base    = room_data["base"] || room_data["name"]
        surface = room_data["surface"].presence&.to_f
        cats    = room_categories[base] || room_categories[room_data["name"]] || category_slugs
        perimeter = estimate_perimeter(surface)

        [1, 2, 3].each do |level|
          totals[level_keys[level]] += compute_room_total(cats, level, geo,
            room_surface: surface, room_perimeter: perimeter,
            project_surface: project_surface, room_base_name: base)
        end
      end
    else
      [1, 2, 3].each do |level|
        totals[level_keys[level]] += compute_room_total(category_slugs, level, geo,
          room_surface: project_surface, room_perimeter: estimate_perimeter(project_surface),
          project_surface: project_surface, room_base_name: nil)
      end
    end

    totals
  end

  def geo_coefficient_for(location_zip)
    return GEO_DEFAULT if location_zip.blank?

    # Extract 5-digit zip from formats like "Paris (75011)" or "75011"
    zip = location_zip.to_s[/(\d{5})/, 1]
    return GEO_DEFAULT unless zip

    # DOM-TOM: use first 3 digits if starts with 97
    dept = zip.start_with?("97") ? zip[0, 3] : zip[0, 2]
    GEO_COEFFICIENTS.fetch(dept, GEO_DEFAULT)
  end

  private

  def estimate_perimeter(surface)
    return nil unless surface && surface > 0
    l_long  = Math.sqrt(surface * 1.5)   # 3:2 ratio rectangle
    l_short = surface / l_long
    (2 * (l_long + l_short)).round(2)
  end

  def generate_items_for_room(room, category_slugs, standing_level, geo, room_surface:, room_perimeter:, project_surface:, room_base_name:)
    category_slugs.each do |slug|
      refs = ReferencePrice.for_category(slug).ordered
      refs.each do |ref|
        next unless ref.applicable_to_room?(room_base_name)

        quantity = ref.compute_quantity(
          room_surface: room_surface, room_perimeter: room_perimeter,
          wall_height: 2.5, project_surface: project_surface
        )

        unit_price_exVAT = ref.unit_price_for(standing_level: standing_level, geo_coefficient: geo)
        material = find_or_build_material(ref)

        room.work_items.create!(
          label: ref.label,
          material: material,
          work_category: material.work_category,
          quantity: quantity,
          unit: ref.unit,
          unit_price_exVAT: unit_price_exVAT,
          vat_rate: ref.vat_rate,
          standing_level: standing_level
        )
      end
    end
  end

  def compute_room_total(category_slugs, standing_level, geo, room_surface:, room_perimeter:, project_surface:, room_base_name:)
    total = 0.0
    category_slugs.each do |slug|
      refs = ReferencePrice.for_category(slug).ordered
      refs.each do |ref|
        next unless ref.applicable_to_room?(room_base_name)

        quantity = ref.compute_quantity(
          room_surface: room_surface, room_perimeter: room_perimeter,
          wall_height: 2.5, project_surface: project_surface
        )

        unit_price_exVAT = ref.unit_price_for(standing_level: standing_level, geo_coefficient: geo)
        line_total_ht    = quantity * unit_price_exVAT
        total += line_total_ht * (1 + ref.vat_rate / 100.0)
      end
    end
    total
  end

  def find_or_build_material(ref)
    db_slug = CATEGORY_SLUG_MAPPING[ref.category_slug] || ref.category_slug
    category = WorkCategory.find_by(slug: ref.category_slug) ||
               WorkCategory.find_by(slug: db_slug) ||
               WorkCategory.create!(slug: ref.category_slug, name: ref.category_slug.humanize)

    reference_key = "#{ref.category_slug}-#{ref.sort_order}"
    Material.find_or_create_by!(brand: "Réf. OpenDevis", reference: reference_key) do |m|
      m.work_category    = category
      m.unit             = ref.unit
      m.public_price_exVAT = ref.total_unit_price_exVAT
      m.vat_rate         = ref.vat_rate
    end
  end
end
