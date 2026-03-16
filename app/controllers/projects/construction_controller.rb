module Projects
  class ConstructionController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def step2
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)
      track_wizard_step(2)
      @project_type    = "construction"
      @renovation_type = "par_piece"
      @selected_rooms  = session[:wizard_rooms] || []
    end

    def save_step2
      @project = find_wizard_project || (redirect_to(wizard_step1_path) && return)

      raw_rooms = params.permit(rooms: [ :name, :base, :surface ]).fetch(:rooms, [])
      room_data = raw_rooms.filter_map do |entry|
        next unless entry[:name].present?
        { "name" => entry[:name], "base" => entry[:base].presence || entry[:name], "surface" => entry[:surface].to_s.strip }
      end

      if room_data.empty?
        @project_type    = "construction"
        @renovation_type = "par_piece"
        @selected_rooms  = []
        @errors          = [ :rooms ]
        render :step2, status: :unprocessable_entity
        return
      end

      # Validate sum of room surfaces does not exceed total project surface
      surface_sum = room_data.sum { |r| r["surface"].to_f }
      if @project.total_surface_sqm.present? && surface_sum > @project.total_surface_sqm.to_f
        @project_type    = "construction"
        @renovation_type = "par_piece"
        @selected_rooms  = room_data
        @errors          = [ :surface_total ]
        render :step2, status: :unprocessable_entity
        return
      end

      session[:wizard_rooms]           = room_data
      session[:wizard_renovation_type] = "par_piece"

      if params[:commit] == "generate"
        category_slugs = session[:wizard_categories] ||
                         Projects::WizardController::CATEGORY_GROUPS.flat_map { |g| g[:slugs] }

        EstimationCalculator.new(@project).generate!(
          category_slugs:  category_slugs,
          standing_levels: [ 1, 2, 3 ],
          room_categories: {},
          rooms_data:      room_data,
          renovation_type: "par_piece"
        )

        %i[wizard_project_id wizard_project_type wizard_renovation_type
           wizard_categories wizard_rooms wizard_room_categories
           wizard_custom_needs wizard_max_step].each { |k| session.delete(k) }

        redirect_to project_path(@project, standing: 2)
      else
        redirect_to wizard_step4_path
      end
    end

    private

    def find_wizard_project
      id = session[:wizard_project_id]
      return nil unless id

      current_user.projects.find_by(id: id)
    end

    def track_wizard_step(step_num)
      current = session[:wizard_max_step].to_i
      session[:wizard_max_step] = [ current, step_num ].max
    end
  end
end
