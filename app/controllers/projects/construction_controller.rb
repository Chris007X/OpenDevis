module Projects
  class ConstructionController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    # GET /projects/construction/step2
    def step2
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)
      @project_type   = "construction"
      @selected_rooms = session[:wizard_rooms] || []
    end

    # POST /projects/construction/step2 (save & go back)
    def save_step2
      session[:wizard_rooms] = parse_rooms
      redirect_to wizard_step1_path
    end

    # POST /projects/construction/generate
    def generate
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)

      session[:wizard_rooms] = parse_rooms
      run_estimation
      clear_wizard_session

      redirect_to project_path(@project, standing: 2)
    end

    private

    def parse_rooms
      raw = params.permit(rooms: %i[name base surface]).fetch(:rooms, [])
      raw.filter_map do |entry|
        next unless entry[:name].present?

        { "name" => entry[:name], "base" => entry[:base].presence || entry[:name],
          "surface" => entry[:surface].to_s.strip }
      end
    end

    def run_estimation
      all_slugs = Projects::WizardController::CATEGORY_GROUPS.flat_map { |g| g[:slugs] }
      category_slugs = session[:wizard_categories] || all_slugs

      EstimationCalculator.new(@project).generate!(
        category_slugs: category_slugs,
        standing_levels: [1, 2, 3],
        room_categories: {},
        rooms_data: session[:wizard_rooms],
        renovation_type: "par_piece"
      )
    end

    def clear_wizard_session
      %i[wizard_project_id wizard_project_type wizard_renovation_type
         wizard_categories wizard_rooms wizard_room_categories
         wizard_custom_needs wizard_max_step].each { |k| session.delete(k) }
    end

    def find_wizard_project
      id = session[:wizard_project_id]
      return nil unless id

      current_user.projects.find_by(id: id)
    end
  end
end
