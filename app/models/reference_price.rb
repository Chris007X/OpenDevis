class ReferencePrice < ApplicationRecord
  VALID_UNITS = %w[m2 ml pce forfait].freeze
  QUANTITY_FORMULAS = %w[surface wall_surface ceiling perimeter project_surface].freeze

  # Standing coefficients: prices stored are Standard; Éco and Premium are derived
  STANDING_COEFFICIENTS = {
    1 => { supply: 0.75, labor: 0.90 },   # Éco
    2 => { supply: 1.00, labor: 1.00 },   # Standard
    3 => { supply: 1.35, labor: 1.15 }    # Premium
  }.freeze

  validates :category_slug,      presence: true
  validates :label,              presence: true
  validates :unit,               presence: true, inclusion: { in: VALID_UNITS }
  validates :supply_price_exVAT, numericality: { greater_than_or_equal_to: 0 }
  validates :labor_price_exVAT,  numericality: { greater_than_or_equal_to: 0 }
  validates :vat_rate,           inclusion: { in: [5, 10, 20] }
  validates :quantity_formula,   presence: true
  validate  :valid_quantity_formula

  scope :for_category, ->(slug) { where(category_slug: slug) }
  scope :ordered,      -> { order(:sort_order, :id) }

  def total_unit_price_exVAT
    supply_price_exVAT + labor_price_exVAT
  end

  # Compute unit price for a given standing level and geo coefficient
  def unit_price_for(standing_level:, geo_coefficient: 1.0)
    coeffs = STANDING_COEFFICIENTS.fetch(standing_level, STANDING_COEFFICIENTS[2])
    adjusted_supply = supply_price_exVAT * coeffs[:supply]
    adjusted_labor  = labor_price_exVAT * coeffs[:labor] * geo_coefficient
    (adjusted_supply + adjusted_labor).round(2)
  end

  def applicable_to_room?(room_base_name)
    return true if applicable_rooms.blank?
    applicable_rooms.split(",").map(&:strip).include?(room_base_name)
  end

  # Compute quantity from room/project dimensions based on formula
  def compute_quantity(room_surface: nil, room_perimeter: nil, wall_height: nil, project_surface: nil)
    case quantity_formula
    when "surface", "ceiling"
      room_surface || project_surface || 20.0
    when "wall_surface"
      (room_perimeter || 12.0) * (wall_height || 2.5)
    when "perimeter"
      room_perimeter || 12.0
    when "project_surface"
      project_surface || 50.0
    when /\Afixed:(\d+(?:\.\d+)?)\z/
      $1.to_f
    when /\Aper_sqm:(\d+(?:\.\d+)?)\z/
      ((room_surface || project_surface || 20.0) * $1.to_f).ceil
    when /\Aper_lm:(\d+(?:\.\d+)?)\z/
      ((room_perimeter || 12.0) * $1.to_f).ceil
    else
      1.0
    end
  end

  private

  def valid_quantity_formula
    return if quantity_formula.blank?
    return if QUANTITY_FORMULAS.include?(quantity_formula)
    return if quantity_formula.match?(/\Afixed:\d+(?:\.\d+)?\z/)
    return if quantity_formula.match?(/\Aper_sqm:\d+(?:\.\d+)?\z/)
    return if quantity_formula.match?(/\Aper_lm:\d+(?:\.\d+)?\z/)
    errors.add(:quantity_formula, "format invalide: #{quantity_formula}")
  end
end
