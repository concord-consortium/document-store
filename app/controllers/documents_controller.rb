class DocumentsController < ApplicationController
  before_filter :auto_authenticate, :only => [:launch]
  before_filter :authenticate_user!, :except => [:index, :show, :all, :open, :save, :delete, :launch]
  before_filter :run_key_or_authenticate, :only => [:index, :show]
  before_filter :load_index_documents, :only => [:index, :all]
  load_and_authorize_resource
  skip_load_and_authorize_resource :only => [:all, :save, :open, :delete, :launch]
  skip_before_filter :verify_authenticity_token, :only => [:save]

  include DocumentsHelper

  cattr_accessor :run_key_generator
  self.run_key_generator = lambda { return SecureRandom.uuid }

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
    document = find_doc_via_params
    render_not_found && return unless document
    content = document.content
    if codap_api_params[:original]
      begin
        authorize! :open_original, document
        content = document.original_content || document.content
      rescue
      end
    else
      authorize! :open, document rescue (render_not_authorized && return)
    end
    render json: content
  end

  def save
    content = request.raw_post
    document = Document.find_or_initialize_by(owner: current_user, title: codap_api_params[:recordname], run_key: codap_api_params[:runKey])
    authorize! :save, document rescue (render_not_authorized && return)
    document.form_content = content
    document.original_content = document.content if document.new_record?
    document.shared = document.content['_permissions'] == 1

    if document.save
      render json: {status: "Created", valid: true }, status: :created
    else
      render json: {status: "Error", errors: document.errors.full_messages, valid: false, message: 'error.writeFailed' }, status: 400
    end
  end

  def delete
    opts = delete_params
    opts[:owner] = current_user.username if current_user
    document = find_doc_via_params(opts)
    (render_not_found && return) unless document
    authorize! :destroy, document rescue (render_not_authorized && return)
    document.destroy
    render json: {success: true}
  end

  def launch
    @codap_server = launch_params[:server]
    @runKey = launch_params[:runKey] || self.run_key_generator.call

    if launch_params[:owner] && (launch_params[:recordname] || launch_params[:doc])
      original_doc = find_doc_via_params(launch_params)
      @master_document_url = codap_link(@codap_server, original_doc) if original_doc
    elsif launch_params[:moreGames]
      moreGames = launch_params[:moreGames]
      moreGames = moreGames.to_json if moreGames.is_a?(Hash) || moreGames.is_a?(Array)
      @master_document_url = codap_link(@codap_server, moreGames)
    end

    @supplemental_documents = Document.where(owner_id: (current_user ? current_user.id : nil), run_key: @runKey)

    @learner_url = Addressable::URI.parse(request.original_url)
    new_query = @learner_url.query_values || {}
    new_query["runKey"] = @runKey
    @learner_url.query_values = new_query
    @learner_url = @learner_url.to_s

    authorize! :open, :url_document
    response.headers.delete 'X-Frame-Options'
    render layout: 'launch'
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

    def find_doc_via_params(p = codap_api_params)
      document = nil
      if title = (p[:recordname] || p[:doc])
        if p[:owner] && !p[:owner].empty?
          owner = User.find_by(username: p[:owner])
          owner_id = owner ? owner.id : -1
        else
          owner_id = nil
        end
        if owner_id != -1
          document = Document.find_by(owner_id: owner_id, title: title, run_key: p[:runKey])
          document = Document.find_by(owner_id: owner_id, title: title, run_key: nil) if document.nil? && !p[:runKey].nil?
        end
      elsif p[:recordid]
        document = Document.includes(:owner).find(p[:recordid]) rescue nil
      end
      return document
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def document_params
      params.require(:document).permit(:title, :content, :shared, :form_content)
    end

    def codap_api_params
      params.permit(:recordname, :recordid, :owner, :runKey, :original)
    end

    def launch_params
      params.permit(:owner, :recordname, :server, :moreGames, :doc, :runKey)
    end

    def delete_params
      params.permit(:recordname, :doc, :runKey)
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
