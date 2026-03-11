module Projects
  class WizardController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    STANDING_MULTIPLIERS = { 1 => 0.75, 2 => 1.0, 3 => 1.40 }.freeze

    # Wizard category reference — slugs used in session, mapped to DB WorkCategory at generation time
    CATEGORY_GROUPS = [
      { name: "Gros œuvre & Structure", slugs: %w[demolition_maconnerie isolation fenetres toiture] },
      { name: "Réseaux & Systèmes", slugs: %w[electricite plomberie ventilation_chauffage] },
      { name: "Menuiseries & Aménagement", slugs: %w[menuiseries_interieures peintures cuisine salle_de_bain_wc] }
    ].freeze

    CATEGORY_LABELS = {
      "demolition_maconnerie"   => { label: "Démolition & maçonnerie",  icon: "🏗️" },
      "isolation"               => { label: "Isolation",                icon: "🧱" },
      "fenetres"                => { label: "Fenêtres",                 icon: "🪟" },
      "toiture"                 => { label: "Toiture & étanchéité",     icon: "🏠" },
      "electricite"             => { label: "Électricité",              icon: "⚡" },
      "plomberie"               => { label: "Plomberie",                icon: "🔧" },
      "ventilation_chauffage"   => { label: "Ventilation & chauffage",  icon: "🌡️" },
      "menuiseries_interieures" => { label: "Menuiseries intérieures",  icon: "🚪" },
      "peintures"               => { label: "Peintures",                icon: "🖌️" },
      "cuisine"                 => { label: "Cuisine",                  icon: "🍳" },
      "salle_de_bain_wc"        => { label: "Salle de bain & WC",      icon: "🚿" }
    }.freeze

    # Maps room names to the only categories allowed for that room in "par pièce" mode
    ROOM_ALLOWED_CATEGORIES = {
      "Salon"   => %w[demolition_maconnerie isolation fenetres electricite ventilation_chauffage menuiseries_interieures peintures],
      "Cuisine" => %w[demolition_maconnerie isolation fenetres electricite plomberie ventilation_chauffage menuiseries_interieures peintures cuisine],
      "Chambre" => %w[demolition_maconnerie isolation fenetres electricite ventilation_chauffage menuiseries_interieures peintures],
      "SDB"     => %w[demolition_maconnerie isolation fenetres electricite plomberie ventilation_chauffage peintures salle_de_bain_wc],
      "WC"      => %w[demolition_maconnerie fenetres electricite plomberie peintures salle_de_bain_wc],
      "Entrée"  => %w[demolition_maconnerie fenetres electricite menuiseries_interieures peintures],
      "Bureau"  => %w[demolition_maconnerie isolation fenetres electricite ventilation_chauffage menuiseries_interieures peintures],
      "Cave"    => %w[demolition_maconnerie isolation electricite ventilation_chauffage peintures],
      "Garage"  => %w[demolition_maconnerie isolation electricite ventilation_chauffage peintures]
    }.freeze

    PRESET_ROOMS = %w[Salon Cuisine Chambre SDB WC Entrée Bureau Cave Garage].freeze

    # ── Choose – Rénovation or Construction ──────────────────────────────────
    def choose
      # Clear previous wizard state when starting fresh
      %i[wizard_project_id wizard_project_type wizard_renovation_type wizard_categories wizard_rooms wizard_room_categories wizard_custom_needs].each do |k|
        session.delete(k)
      end
    end

    def save_choose
      session[:wizard_project_type] = params[:project_type].in?(%w[renovation construction extension]) ? params[:project_type] : "renovation"
      redirect_to wizard_step1_path
    end

    # ── Step 1 – Property info ────────────────────────────────────────────────
    def step1
      redirect_to(wizard_choose_path) && return unless session[:wizard_project_type]

      @project_type = session[:wizard_project_type]
      if (id = session[:wizard_project_id])
        @project = current_user.projects.find_by(id: id) || Project.new
      else
        @project = Project.new
      end
    end

    def save_step1
      if (id = session[:wizard_project_id])
        @project = current_user.projects.find_by(id: id) || current_user.projects.build
      else
        @project = current_user.projects.build
      end

      # Build property_url from property_type params
      property_url = resolve_property_type
      @project.assign_attributes(step1_params.merge(status: :draft, property_url: property_url))

      # Server-side validation for required fields
      @errors = []
      @errors << :property_type if property_url.blank?
      @errors << :total_surface_sqm if @project.total_surface_sqm.blank? || @project.total_surface_sqm <= 0
      @errors << :location_zip if @project.location_zip.blank?

      if @errors.any?
        @project_type = session[:wizard_project_type]
        render :step1, status: :unprocessable_entity
        return
      end

      if @project.save
        session[:wizard_project_id] = @project.id
        if session[:wizard_project_type].in?(%w[construction extension])
          session[:wizard_renovation_type] = session[:wizard_project_type]
          redirect_to wizard_step3_path
        else
          redirect_to wizard_step2_path
        end
      else
        @project_type = session[:wizard_project_type]
        render :step1, status: :unprocessable_entity
      end
    end

    # ── Step 2 – Renovation type ──────────────────────────────────────────────
    def step2
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)
      @renovation_type = session[:wizard_renovation_type]
      @selected_rooms  = session[:wizard_rooms] || []
    end

    def save_step2
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)
      # Reset step 3 selections when renovation type changes
      if session[:wizard_renovation_type] != params[:renovation_type]
        session.delete(:wizard_categories)
      end

      session[:wizard_renovation_type] = params[:renovation_type]

      if params[:renovation_type] == "par_piece"
        # Build structured room data: [{ "name" => "Salon", "count" => "2", "reno_type" => "renovation_legere" }]
        checked_rooms = (params[:rooms] || []).filter_map { |r| r[:name].presence }
        details = params[:room_details] || {}

        room_data = checked_rooms.map do |name|
          d = details[name] || {}
          { "name" => name, "count" => (d[:count] || 1).to_s, "reno_type" => d[:reno_type] || "renovation_legere" }
        end

        if room_data.empty?
          @renovation_type = params[:renovation_type]
          @selected_rooms = []
          @errors = [:rooms]
          render :step2, status: :unprocessable_entity
          return
        end

        session[:wizard_rooms] = room_data
      else
        session[:wizard_rooms] = []
      end

      redirect_to wizard_step3_path
    end

    # ── Step 3 – Work categories ──────────────────────────────────────────────
    def step3
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)
      @project_type        = session[:wizard_project_type]
      @renovation_type     = session[:wizard_renovation_type]
      @is_maison           = @project.property_url == "maison"
      @selected_rooms      = session[:wizard_rooms] || []
      @category_groups     = build_category_groups
      @category_labels     = CATEGORY_LABELS
      @room_allowed_categories = ROOM_ALLOWED_CATEGORIES

      if session[:wizard_categories].present?
        # User already visited step 3 — restore their selections
        @selected_categories = session[:wizard_categories]
      else
        # First visit — compute defaults based on renovation type
        @selected_categories = default_categories_for(@renovation_type, @selected_rooms)
      end
    end

    def save_step3
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)

      if session[:wizard_renovation_type] == "par_piece"
        # Store per-room categories and compute flat unique list
        rc = params[:room_categories]&.to_unsafe_h || {}
        session[:wizard_room_categories] = rc
        session[:wizard_categories] = rc.values.flatten.uniq.reject(&:blank?)
      else
        session[:wizard_categories] = params[:categories]&.reject(&:blank?) || []
      end

      session[:wizard_custom_needs] = params[:custom_needs].to_s.strip
      redirect_to wizard_step4_path
    end

    # ── Step 4 – Recap + generate ─────────────────────────────────────────────
    def step4
      @project          = find_wizard_project || (redirect_to(wizard_step1_path) && return)
      @project_type     = session[:wizard_project_type]
      @renovation_type  = session[:wizard_renovation_type]
      @selected_rooms   = session[:wizard_rooms] || []
      @selected_cats    = load_selected_categories
    end

    def generate
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)

      standing         = params[:standing].to_i.clamp(1, 3)
      renovation_type  = session[:wizard_renovation_type]
      category_slugs   = session[:wizard_categories] || []
      room_categories  = session[:wizard_room_categories] || {}

      if renovation_type == "par_piece" && session[:wizard_rooms].present?
        session[:wizard_rooms].each do |room_data|
          name  = room_data["name"]
          count = (room_data["count"] || 1).to_i
          cats  = room_categories[name] || category_slugs

          count.times do |i|
            room_label = count > 1 ? "#{name} #{i + 1}" : name
            room = @project.rooms.create!(name: room_label)
            generate_work_items(room, cats, standing)
          end
        end
      else
        room = @project.rooms.create!(name: "Ensemble des travaux")
        generate_work_items(room, category_slugs, standing)
      end

      @project.recompute_totals!

      # Clear wizard session state
      %i[wizard_project_id wizard_project_type wizard_renovation_type wizard_categories wizard_rooms wizard_room_categories wizard_custom_needs].each do |k|
        session.delete(k)
      end

      redirect_to project_path(@project, standing: standing), notice: "Estimation générée !"
    end

    private

    def find_wizard_project
      id = session[:wizard_project_id]
      return nil unless id

      current_user.projects.find_by(id: id)
    end

    def step1_params
      params.require(:project).permit(:location_zip, :total_surface_sqm, :room_count, :energy_rating, :description)
    end

    def resolve_property_type
      pt = params.dig(:project, :property_type)
      case pt
      when "appartement", "maison" then pt
      when "autre"
        autre = params.dig(:project, :property_type_autre).to_s.strip
        autre.present? ? autre : nil
      end
    end

    def build_category_groups
      # For "energetique": only show energy-related categories
      energy_only_slugs = %w[isolation fenetres ventilation_chauffage]

      CATEGORY_GROUPS.filter_map do |group|
        slugs = group[:slugs].dup
        # Toiture only for maison
        slugs.reject! { |s| s == "toiture" } unless @is_maison
        # Energetique: filter to energy-related slugs only
        slugs.select! { |s| energy_only_slugs.include?(s) } if @renovation_type == "energetique"
        slugs.any? ? { name: group[:name], slugs: slugs } : nil
      end
    end

    def default_categories_for(_renovation_type, _rooms)
      [] # Always start unchecked — user opts in
    end

    def load_selected_categories
      slugs = session[:wizard_categories] || []
      slugs.filter_map { |s| CATEGORY_LABELS[s]&.merge(slug: s) }
    end

    def generate_work_items(room, category_slugs, standing_level)
      multiplier   = STANDING_MULTIPLIERS[standing_level] || 1.0
      surface      = @project.total_surface_sqm || 20
      area_slugs   = %w[peinture carrelage isolation]

      category_slugs.each do |slug|
        category = WorkCategory.find_by(slug: slug)
        next unless category

        category.materials.limit(3).each do |material|
          base_price = material.public_price_exVAT || 50
          qty        = area_slugs.include?(slug) ? surface : 1
          unit       = area_slugs.include?(slug) ? "m²" : (material.unit.presence || "u")

          room.work_items.create!(
            label: [category.name, material.brand, material.reference].compact.join(" — "),
            material: material,
            work_category: category,
            quantity: qty,
            unit: unit,
            unit_price_exVAT: (base_price * multiplier).round(2),
            vat_rate: material.vat_rate || 10,
            standing_level: standing_level
          )
        end
      end
    end
  end
end
