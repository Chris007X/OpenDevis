module Projects
  class WizardController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

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
      "peintures"               => { label: "Peintures",                icon: "🎨" },
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

    helper_method :wizard_max_step

    # ── Choose – Rénovation or Construction ──────────────────────────────────
    def choose
      # Clear previous wizard state when starting fresh
      %i[wizard_project_id wizard_project_type wizard_renovation_type wizard_categories wizard_rooms wizard_room_categories wizard_custom_needs wizard_max_step].each do |k|
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

      track_wizard_step(1)
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
      # For construction flow, property type is not shown — use a default
      property_url = "construction" if property_url.blank? && session[:wizard_project_type] == "construction"
      @project.assign_attributes(step1_params.merge(status: :in_progress, property_url: property_url))

      # Server-side validation for required fields
      @errors = []
      @errors << :property_type if property_url.blank?
      @errors << :total_surface_sqm if @project.total_surface_sqm.blank? || @project.total_surface_sqm <= 0
      # Accept "75001" or "Paris (75001)" — extract and validate the 5-digit postal code
      zip = @project.location_zip.to_s.strip
      zip_digits = zip[/(\d{5})/, 1]
      @errors << :location_zip if zip.blank? || zip_digits.nil?
      @errors.uniq!

      if @errors.any?
        @project_type = session[:wizard_project_type]
        render :step1, status: :unprocessable_entity
        return
      end

      if @project.save
        session[:wizard_project_id] = @project.id
        if session[:wizard_project_type] == "construction"
          session[:wizard_renovation_type] = "construction"
          session[:wizard_categories] = CATEGORY_GROUPS.flat_map { |g| g[:slugs] }
          redirect_to wizard_step2_path
        elsif session[:wizard_project_type] == "extension"
          session[:wizard_renovation_type] = "extension"
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
      track_wizard_step(2)
      @project_type    = session[:wizard_project_type]
      @renovation_type = session[:wizard_renovation_type]
      @selected_rooms  = session[:wizard_rooms] || []
    end

    def save_step2
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)

      session[:wizard_renovation_type] = params[:renovation_type]

      if params[:renovation_type] == "par_piece"
        # params[:rooms] is an array of hashes: [{ name: "Salon", base: "Salon", surface: "30" }, ...]
        raw_rooms = params.permit(rooms: [ :name, :base, :surface ]).fetch(:rooms, [])
        room_data = raw_rooms.filter_map do |entry|
          next unless entry[:name].present?
          { "name" => entry[:name], "base" => entry[:base].presence || entry[:name], "surface" => entry[:surface].to_s.strip }
        end

        if room_data.empty?
          @renovation_type = params[:renovation_type]
          @selected_rooms = session[:wizard_rooms] || []
          @errors = [:rooms]
          render :step2, status: :unprocessable_entity
          return
        end

        # Validate sum of room surfaces does not exceed total project surface
        surface_sum = room_data.sum { |r| r["surface"].to_f }
        if @project.total_surface_sqm.present? && surface_sum > @project.total_surface_sqm.to_f
          @renovation_type = params[:renovation_type]
          @selected_rooms = room_data
          @errors = [:surface_total]
          @project_type = session[:wizard_project_type]
          render :step2, status: :unprocessable_entity
          return
        end

        session[:wizard_rooms] = room_data
      end
      # Note: when switching to renovation_complete, we keep wizard_rooms in session
      # so room data is restored if user switches back to par_piece.

      if session[:wizard_project_type] == "construction"
        redirect_to wizard_step4_path
      else
        redirect_to wizard_step3_path
      end
    end

    # ── Step 3 – Work categories ──────────────────────────────────────────────
    def step3
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)
      track_wizard_step(3)
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

    # ── Chat IA – AJAX endpoint ───────────────────────────────────────────────
    def chat_property
      history = (params[:history] || []).map do |msg|
        { role: msg[:role].to_s, content: msg[:content].to_s }
      end
      result = ::PropertyChatAnalyzer.new(history).chat
      render json: result
    rescue => e
      render json: { reply: friendly_error(e.message), data: {}, complete: false }, status: :unprocessable_entity
    end

    # ── URL analyzer – AJAX endpoint ─────────────────────────────────────────
    def analyze_url
      url = params[:url].to_s.strip
      result = ::PropertyUrlAnalyzer.new(url).analyze
      render json: { success: true, data: result }
    rescue => e
      render json: { success: false, error: friendly_error(e.message) }, status: :unprocessable_entity
    end

    # ── Photo upload – AJAX endpoint ─────────────────────────────────────────
    def upload_photo
      file = params[:photo]
      return render json: { error: "Fichier manquant" }, status: :bad_request unless file

      validate_photo!(file)
      render json: { photo_url: save_photo(file) }
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # ── PDF analyzer – AJAX endpoint ─────────────────────────────────────────
    def analyze_pdf
      file = params[:file]
      raise "Aucun fichier reçu."                  unless file
      raise "Le fichier doit être un PDF."          unless file.content_type&.include?("pdf")
      raise "Fichier trop volumineux (max 10 Mo)."  if file.size > 10.megabytes

      result = ::PdfPropertyAnalyzer.new(file.tempfile).analyze
      render json: { success: true, data: result }
    rescue => e
      render json: { success: false, error: friendly_error(e.message) }, status: :unprocessable_entity
    end

    # ── Edit – Restore wizard session from existing project and go to step4 ──
    def edit_recap
      @project = current_user.projects.find(params[:id])

      # Restore wizard session state from the existing project
      session[:wizard_project_id]   = @project.id
      session[:wizard_project_type] = "renovation"

      rooms = @project.rooms.includes(work_items: :work_category)

      if rooms.size == 1 && rooms.first.name == "Ensemble des travaux"
        session[:wizard_renovation_type] = "renovation_complete"
        session[:wizard_rooms] = []
        # Restore selected categories from work items
        slugs = rooms.first.work_items.map { |wi| wi.work_category&.slug }.compact.uniq
        session[:wizard_categories] = slugs
        session[:wizard_room_categories] = {}
      else
        session[:wizard_renovation_type] = "par_piece"
        room_data = []
        room_categories = {}
        rooms.each do |room|
          # Infer base name by stripping trailing number (e.g. "Chambre 2" → "Chambre")
          base = room.name.sub(/\s+\d+\z/, "")
          room_data << { "name" => room.name, "base" => base, "surface" => room.surface_sqm&.to_s || "" }
          slugs = room.work_items.map { |wi| wi.work_category&.slug }.compact.uniq
          room_categories[room.name] = slugs if slugs.any?
        end
        session[:wizard_rooms] = room_data
        session[:wizard_room_categories] = room_categories
        session[:wizard_categories] = room_categories.values.flatten.uniq
      end

      redirect_to wizard_step4_path
    end

    # ── Step 4 – Recap + generate ─────────────────────────────────────────────
    def step4
      @project          = find_wizard_project || (redirect_to(wizard_step1_path) && return)
      track_wizard_step(4)
      @project_type     = session[:wizard_project_type]
      @renovation_type  = session[:wizard_renovation_type]
      @selected_rooms   = session[:wizard_rooms] || []
      @selected_cats    = load_selected_categories
      @room_categories  = session[:wizard_room_categories] || {}
      @category_labels  = CATEGORY_LABELS
    end

    def generate
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)

      renovation_type  = session[:wizard_renovation_type]
      category_slugs   = session[:wizard_categories] || []
      room_categories  = session[:wizard_room_categories] || {}
      rooms_data       = session[:wizard_rooms] || []

      EstimationCalculator.new(@project).generate!(
        category_slugs:  category_slugs,
        standing_levels: [1, 2, 3],
        room_categories: room_categories,
        rooms_data:      rooms_data,
        renovation_type: renovation_type || "renovation_complete"
      )

      # Clear wizard session state
      %i[wizard_project_id wizard_project_type wizard_renovation_type
         wizard_categories wizard_rooms wizard_room_categories
         wizard_custom_needs wizard_max_step].each { |k| session.delete(k) }

      redirect_to project_path(@project, standing: 2)
    end

    private

    def friendly_error(message)
      case message
      when /HTTP 403/, /HTTP 401/
        "Ce site bloque l'accès automatique. Copiez-collez les informations manuellement."
      when /HTTP 404/
        "Annonce introuvable. Vérifiez que le lien est correct et que l'annonce est toujours en ligne."
      when /HTTP 5/, /HTTP 503/, /HTTP 502/
        "Le site est temporairement indisponible. Réessayez dans quelques instants."
      when /timeout/, /Timeout/, /timed out/
        "La page met trop de temps à répondre. Vérifiez votre connexion ou essayez un autre lien."
      when /LLM API error/
        "Impossible d'analyser le contenu de cette page. Remplissez les informations manuellement."
      when /getaddrinfo/, /SocketError/, /connection/i
        "Impossible de se connecter à ce site. Vérifiez que le lien est correct."
      when /lisible/, /corrompu/, /illisible/, /volumineux/, /Aucun fichier/, /doit être un PDF/
        message
      else
        "Ce lien n'a pas pu être analysé. Remplissez les informations manuellement."
      end
    end

    def validate_photo!(file)
      allowed = %w[image/jpeg image/png image/webp image/gif]
      raise "Format non supporté (JPG, PNG, WEBP, GIF uniquement)" unless allowed.include?(file.content_type)
      raise "Fichier trop grand (max 5 Mo)" if file.size > 5.megabytes
    end

    def save_photo(file)
      dir = Rails.root.join("public/uploads/wizard_photos")
      FileUtils.mkdir_p(dir)
      ext = File.extname(file.original_filename).downcase.presence || ".jpg"
      filename = "#{SecureRandom.hex(12)}#{ext}"
      FileUtils.cp(file.tempfile.path, dir.join(filename))
      "/uploads/wizard_photos/#{filename}"
    end

    def track_wizard_step(step_num)
      current = session[:wizard_max_step].to_i
      session[:wizard_max_step] = [ current, step_num ].max
    end

    def wizard_max_step
      session[:wizard_max_step].to_i
    end

    def find_wizard_project
      id = session[:wizard_project_id]
      return nil unless id

      current_user.projects.find_by(id: id)
    end

    def step1_params
      params.require(:project).permit(
        :name, :location_zip, :total_surface_sqm, :room_count, :energy_rating, :description, :photo_url
      )
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

  end
end
