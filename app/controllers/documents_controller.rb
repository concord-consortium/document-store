class DocumentsController < ApplicationController
  before_filter :auto_authenticate, :only => [:launch]
  before_filter :authenticate_user!, :except => [:all, :open, :save, :launch]
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
      format.html { redirect_to documents_url, notice: 'Document was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  # CODAP API
  def all
    authorize! :all, Document rescue (render_not_authorized && return)
    documents = current_user.documents
    render json: documents.map {|d| {name: d.title, id: d.id, _permissions: (d.shared ? 1 : 0) } }
  end

  def open
    if codap_api_params[:recordname] && codap_api_params[:owner]
      owner = User.find_by(username: codap_api_params[:owner])
      document = owner && Document.find_by(owner: owner, title: codap_api_params[:recordname])
    elsif codap_api_params[:recordid]
      document = Document.includes(:owner).find(codap_api_params[:recordid]) rescue nil
    else
      render_not_found && return
    end
    render_not_found && return unless document
    authorize! :open, document rescue (render_not_authorized && return)
    render json: document.content
  end

  def save
    content = request.raw_post
    document = Document.find_or_initialize_by(owner: current_user, title: codap_api_params[:recordname])
    authorize! :save, document rescue (render_not_authorized && return)
    document.form_content = content
    document.shared = document.content['_permissions'] == 1

    if document.save
      render json: {status: "Created", valid: true }, status: :created
    else
      render json: {status: "Error", errors: document.errors.full_messages, valid: false, message: 'error.writeFailed' }, status: 400
    end
  end

  def launch
    codap_query = '?'
    codap_query += "documentServer=" + URI.encode_www_form_component(root_url).gsub("+", "%20")
    if launch_params[:owner] && (title = (launch_params[:recordname] || launch_params[:doc]))
      codap_query += "&doc=" + URI.encode_www_form_component(title).gsub("+", "%20")
      codap_query += "&owner=" + URI.encode_www_form_component(launch_params[:owner]).gsub("+", "%20")
    elsif launch_params[:moreGames]
      moreGames = launch_params[:moreGames]
      moreGames = moreGames.to_json if moreGames.is_a?(Hash) || moreGames.is_a?(Array)
      codap_query += "&moreGames=" + URI.encode_www_form_component(moreGames).gsub("+", "%20")
    else
      codap_query += "&doc=notfound&owner=nobody"
    end

    authorize! :open, :url_document
    redirect_to URI.parse(launch_params[:server]).merge(codap_query).to_s
  end

  private
    def load_index_documents
      @documents = current_user ? current_user.documents : []
    end

    def auto_authenticate
      unless current_user
        provider = auth_params[:auth_provider]
        if referer = request.env['HTTP_REFERER'] || provider
          Concord::AuthPortal.all.each_pair do |key,portal|
            if (referer && referer.include?(portal.url)) ||  # may fail if the protocol differs
               (provider && provider.include?(portal.url))
              # we came from a configured authentication provider
              # so let's authenticate ourselves
              session[:user_return_to] = request.original_url
              redirect_to omniauth_authorize_path("user", portal.strategy_name)
              return
            end
          end
        end
      end
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def document_params
      params.require(:document).permit(:title, :content, :shared, :form_content)
    end

    def codap_api_params
      params.permit(:username, :recordname, :recordid, :owner)
    end

    def launch_params
      params.permit(:owner, :recordname, :server, :moreGames, :doc)
    end

    def auth_params
      params.permit(:auth_provider)
    end

    def render_not_found
      authorize! :not_found, :nil_document
      render json: {valid: false, message: "error.notFound"}, status: 404
    end

    def render_not_authorized
      authorize! :not_authorized, :nil_document
      render json: {valid: false, message: "error.permissions"}, status: 403
    end
end
