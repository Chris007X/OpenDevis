class DocumentsController < ApplicationController
  before_action :set_project, only: %i[index new create]
  before_action :set_document, only: [:destroy]

  def index
    @documents = policy_scope(Document).where(project: @project).order(uploaded_at: :desc)
  end

  def new
    @document = Document.new(project: @project)
    authorize @document
  end

  def create
    @document = Document.new(document_params)
    @document.project = @project
    @document.uploaded_at = Time.current
    authorize @document
    if @document.save
      redirect_to @project, notice: "Document ajouté."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @project = @document.project
    @document.destroy
    redirect_to @project, notice: "Document supprimé."
  end

  private

  def set_project
    @project = policy_scope(Project).find(params[:project_id])
  end

  def set_document
    @document = Document.find(params[:id])
    authorize @document
  end

  def document_params
    params.require(:document).permit(:file_name, :file_type, :file_url)
  end
end
