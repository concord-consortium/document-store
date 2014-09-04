class DocumentsController < ApplicationController
  before_filter :auto_authenticate, :only => [:launch]
  before_filter :authenticate_user!, :except => [:index, :show, :all, :open, :save, :launch]
  before_filter :run_key_or_authenticate, :only => [:index, :show]
  before_filter :load_index_documents, :only => [:index, :all]
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
    render json: @documents.map {|d| {name: d.title, id: d.id, _permissions: (d.shared ? 1 : 0) } }
  end

  def open
    if codap_api_params[:recordname]
      if codap_api_params[:owner] && !codap_api_params[:owner].empty?
        owner = User.find_by(username: codap_api_params[:owner])
        owner_id = owner ? owner.id : -1
      else
        owner_id = nil
      end
      if owner_id != -1
        document = Document.find_by(owner_id: owner_id, title: codap_api_params[:recordname], run_key: codap_api_params[:runKey])
        document = Document.find_by(owner_id: owner_id, title: codap_api_params[:recordname], run_key: nil) if document.nil?
      end
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
    document = Document.find_or_initialize_by(owner: current_user, title: codap_api_params[:recordname], run_key: codap_api_params[:runKey])
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
      if current_user
        if codap_api_params[:runKey]
          @documents = Document.where(owner_id: current_user.id, run_key: codap_api_params[:runKey])
        else
          @documents = current_user.documents
        end
      else
        if codap_api_params[:runKey]
          @documents = Document.where(owner_id: nil, run_key: codap_api_params[:runKey])
        else
          @documents = []
        end
      end
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
              return true
            end
          end
        end
      end
    end


    def run_key_or_authenticate
      return true if codap_api_params[:runKey]
      return authenticate_user!
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def document_params
      params.require(:document).permit(:title, :content, :shared, :form_content)
    end

    def codap_api_params
      params.permit(:recordname, :recordid, :owner, :runKey)
    end

    def launch_params
      params.permit(:owner, :recordname, :server, :moreGames, :doc, :runKey)
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
