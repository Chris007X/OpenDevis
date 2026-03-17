class TestRunsController < ApplicationController
  before_action :require_admin!, only: [ :index, :show ]

  protect_from_forgery with: :null_session, only: [ :create ]
  skip_before_action :authenticate_user!, only: [ :create ]

  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # GET /test_runs
  def index
    @test_runs = TestRun.recent
  end

  # GET /test_runs/:id
  def show
    @test_run = TestRun.find(params[:id])
  end

  # POST /test_runs  — token-authenticated JSON API for the E2E suite
  def create
    unless valid_api_token?
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    @test_run = TestRun.new(test_run_params)

    if @test_run.save
      render json: { id: @test_run.id }, status: :created
    else
      render json: { errors: @test_run.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def require_admin!
    redirect_to root_path, alert: "Accès non autorisé." unless current_user&.admin?
  end

  def valid_api_token?
    expected = ENV["OPENDEVIS_TEST_TOKEN"].presence
    return false if expected.nil?

    provided = request.headers["Authorization"].to_s.delete_prefix("Bearer ").strip
    ActiveSupport::SecurityUtils.secure_compare(expected, provided)
  end

  def test_run_params
    params.require(:test_run).permit(
      :ran_at, :pages_total, :pages_passed,
      :flows_total, :flows_passed,
      :ui_total, :ui_passed,
      :errors_count, :duration_seconds, :trigger,
      results: {}
    )
  end
end
