class DocumentsController < ApplicationController
  before_filter :authenticate_user!, :except => [:all, :open, :save]
  before_filter :load_index_documents, :only => [:index]
  load_and_authorize_resource
  skip_load_and_authorize_resource :only => [:all, :save, :open, :launch]
  skip_before_filter :verify_authenticity_token, :only => [:save]

  # GET /documents
  # GET /documents.json
  def index
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
    authorize! :all, Document
    documents = current_user.documents
    render json: documents.map {|d| {name: d.title, id: d.id, _permissions: (d.shared ? 1 : 0) } }
  end

  def open
    if codap_api_params[:recordname] && codap_api_params[:owner]
      owner = User.find_by(username: codap_api_params[:owner])
      raise ActiveRecord::RecordNotFound unless owner
      document = Document.find_by(owner: owner, title: codap_api_params[:recordname])
      authorize! :open, document
    elsif codap_api_params[:recordid]
      document = Document.includes(:owner).find(codap_api_params[:recordid])
      authorize! :open, document
    else
      raise ActiveRecord::RecordNotFound
    end
    render json: document.content
  end

  def save
    content = request.raw_post
    document = Document.find_or_initialize_by(owner: current_user, title: codap_api_params[:recordname])
    authorize! :save, document
    document.form_content = content

    if document.save
      render json: {status: "Created"}, status: :created
    else
      render json: {status: "Error", errors: document.errors.full_messages }, status: 400
    end
  end

  def launch
    owner = User.find_by(username: launch_params[:owner])
    raise ActiveRecord::RecordNotFound unless owner
    document = Document.find_by(owner: owner, title: launch_params[:recordname])
    authorize! :open, document
    codap_query = '?'
    codap_query += "doc=" + URI.encode_www_form_component(document.title).gsub("+", "%20")
    codap_query += "&owner=" + URI.encode_www_form_component(owner.username).gsub("+", "%20")
    codap_query += "&documentServer=" + URI.encode_www_form_component(root_url).gsub("+", "%20")
    redirect_to URI.parse(launch_params[:server]).merge(codap_query).to_s
  end

  private
    def load_index_documents
      @documents = current_user ? current_user.documents : []
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def document_params
      params.require(:document).permit(:title, :content, :shared, :form_content)
    end

    def codap_api_params
      params.permit(:username, :recordname, :recordid, :owner)
    end

    def launch_params
      params.permit(:owner, :recordname, :server)
    end
end
