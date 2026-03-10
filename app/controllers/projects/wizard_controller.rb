module Projects
  class WizardController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    STANDING_MULTIPLIERS = { 1 => 0.75, 2 => 1.0, 3 => 1.40 }.freeze

    CATEGORY_GROUPS = [
      { name: "Structure & Réseaux", icon: "🏗️", slugs: %w[electricite plomberie maconnerie] },
      { name: "Énergie & Confort", icon: "🌡️", slugs: %w[isolation chauffage] },
      { name: "Menuiseries & Aménagement", icon: "🚪", slugs: %w[menuiserie peinture carrelage] }
    ].freeze

    PRESET_ROOMS = %w[Salon Cuisine Chambre SDB WC Entrée Bureau Cave Garage].freeze

    # ── Step 1 – Property info ────────────────────────────────────────────────
    def step1
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

      @project.assign_attributes(step1_params.merge(status: :draft))

      if @project.save
        session[:wizard_project_id] = @project.id
        redirect_to wizard_step2_path
      else
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
      session[:wizard_renovation_type] = params[:renovation_type]
      session[:wizard_rooms] = params[:rooms]&.reject(&:blank?) || []
      redirect_to wizard_step3_path
    end

    # ── Step 3 – Work categories ──────────────────────────────────────────────
    def step3
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)
      @renovation_type     = session[:wizard_renovation_type]
      @selected_categories = session[:wizard_categories] || []
      @category_groups     = build_category_groups(@renovation_type)
    end

    def save_step3
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)
      session[:wizard_categories] = params[:categories]&.reject(&:blank?) || []
      redirect_to wizard_step4_path
    end

    # ── Step 4 – Recap + generate ─────────────────────────────────────────────
    def step4
      @project          = find_wizard_project || (redirect_to(wizard_step1_path) && return)
      @renovation_type  = session[:wizard_renovation_type]
      @selected_rooms   = session[:wizard_rooms] || []
      @selected_cats    = load_selected_categories
    end

    def generate
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)

      standing         = params[:standing].to_i.clamp(1, 3)
      renovation_type  = session[:wizard_renovation_type]
      category_slugs   = session[:wizard_categories] || []
      room_names       = if renovation_type == "par_piece" && session[:wizard_rooms].present?
                           session[:wizard_rooms]
                         else
                           ["Ensemble des travaux"]
                         end

      room_names.each do |room_name|
        room = @project.rooms.create!(name: room_name)
        generate_work_items(room, category_slugs, standing)
      end

      @project.recompute_totals!

      # Clear wizard session state
      %i[wizard_project_id wizard_renovation_type wizard_categories wizard_rooms].each do |k|
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
      params.require(:project).permit(:location_zip, :total_surface_sqm, :room_count, :energy_rating, :property_url)
    end

    def build_category_groups(renovation_type)
      all_cats = WorkCategory.all.index_by(&:slug)

      source_groups = if renovation_type == "energetique"
                        CATEGORY_GROUPS.select { |g| g[:name].include?("Énergie") }
                      else
                        CATEGORY_GROUPS
                      end

      source_groups.filter_map do |group|
        cats = group[:slugs].filter_map { |slug| all_cats[slug] }
        cats.any? ? group.merge(categories: cats) : nil
      end
    end

    def load_selected_categories
      slugs = session[:wizard_categories] || []
      WorkCategory.where(slug: slugs).index_by(&:slug).values_at(*slugs).compact
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
