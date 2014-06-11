class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :edit, :update, :destroy]

  # GET /documents
  # GET /documents.json
  def index
    @documents = Document.all
  end

  # GET /documents/1
  # GET /documents/1.json
  def show
  end

  # GET /documents/new
  def new
    @document = Document.new
  end

  # GET /documents/1/edit
  def edit
  end

  # POST /documents
  # POST /documents.json
  def create
    @document = Document.new(document_params)
    @document.owner = current_user

    respond_to do |format|
      if @document.save
        format.html { redirect_to @document, notice: 'Document was successfully created.' }
        format.json { render :show, status: :created, location: @document }
      else
        format.html { render :new }
        format.json { render json: @document.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /documents/1
  # PATCH/PUT /documents/1.json
  def update
    respond_to do |format|
      if @document.update(document_params)
        format.html { redirect_to @document, notice: 'Document was successfully updated.' }
        format.json { render :show, status: :ok, location: @document }
      else
        format.html { render :edit }
        format.json { render json: @document.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /documents/1
  # DELETE /documents/1.json
  def destroy
    @document.destroy
    respond_to do |format|
      format.html { redirect_to documents_url, notice: 'Document was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  # CODAP API
  def all
    user = User.find_by_username(codap_api_params[:username])
    raise ActiveRecord::RecordNotFound unless user
    documents = user.documents
    render json: documents.map {|d| d.content }
  end

  def open
    if codap_api_params[:recordname] && codap_api_params[:owner]
      owner = User.find_by_username(codap_api_params[:owner])
      raise ActiveRecord::RecordNotFound unless owner
      document = Document.find_by_owner_id_and_title(owner, codap_api_params[:recordname])
      raise ActiveRecord::RecordNotFound unless document && document.shared
    elsif codap_api_params[:recordid]
      document = Document.includes(:owner).find(codap_api_params[:recordid])
      raise ActiveRecord::RecordNotFound unless document && document.owner && document.owner.username == codap_api_params[:username]
    else
      raise ActiveRecord::RecordNotFound
    end
    render json: document.content
  end

  def save
    user = User.find_by_username(codap_api_params[:username])
    raise ActiveRecord::RecordNotFound unless user

    content = request.raw_post
    Rails.logger.fatal "Content is: '#{content}'"
    @document = Document.new(owner: user, title: codap_api_params[:recordname], form_content: content)

    if @document.save
      render json: {status: "Created"}, status: :created
    else
      render json: {status: "Error", errors: @document.errors.full_messages }, status: 400
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_document
      @document = Document.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def document_params
      params.require(:document).permit(:title, :content, :shared, :form_content)
    end

    def codap_api_params
      params.permit(:username, :recordname, :recordid, :owner)
    end
end
