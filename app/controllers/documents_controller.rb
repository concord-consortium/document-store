class DocumentsController < ApplicationController
  before_filter :auto_authenticate, :only => [:launch, :report]
  before_filter :authenticate_user!, :except => [:index, :show, :all, :open, :save, :patch, :delete, :launch, :rename, :report]
  before_filter :run_key_or_authenticate, :only => [:index, :show]
  before_filter :load_index_documents, :only => [:index, :all]
  load_and_authorize_resource
  skip_load_and_authorize_resource :only => [:all, :save, :patch, :open, :delete, :launch, :rename, :report]
  skip_before_filter :verify_authenticity_token, :only => [:save, :patch]

  before_filter :check_session_expiration, :only => [:all, :save, :patch, :open, :delete, :rename]

  include DocumentsHelper

  cattr_accessor :run_key_generator
  self.run_key_generator = lambda { return SecureRandom.uuid }

  # GET /documents
  # GET /documents.json
  def index
    @documents = @documents.paginate(page: index_params[:page], :per_page => 20) if @documents.respond_to?('paginate')
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
    render json: @documents.where(is_codap_main_document: true).map {|d| {name: d.title, id: d.id, _permissions: (d.shared ? 1 : 0) } }
  end

  def open
    document = find_doc_via_params
    new_doc = nil
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
    if document.owner != current_user
      content["_permissions"] = 0 if content && content.is_a?(Hash) && content.has_key?("_permissions")
      if can? :save, :document
        # create a copy of this document under the current user or current run key if it doesn't already exist, with the original_content set
        new_doc = Document.find_or_initialize_by(owner: current_user, title: document.title, run_key: codap_api_params[:runKey] )
        if new_doc.new_record?
          new_doc.content = content
          new_doc.original_content = content
          new_doc.save
        else
          content = new_doc.content
        end
      end
    end
    response.headers['Document-Id'] = "#{new_doc.nil? ? document.id : new_doc.id}"
    render json: content
  end

  def save
    content = request.raw_post

    if codap_api_params[:recordid].present?
      document = Document.find(codap_api_params[:recordid].to_i)
    else
      document = Document.find_or_initialize_by(owner: current_user, title: codap_api_params[:recordname], run_key: codap_api_params[:runKey])
    end
    authorize! :save, document rescue (render_not_authorized && return)

    document.form_content = content
    document.original_content = document.content if document.new_record?
    document.shared = document.content.is_a?(Hash) && document.content.has_key?('_permissions') && document.content['_permissions'].to_i == 1

    if document.save
      render json: {status: "Created", valid: true, id: document.id }, status: :created
    else
      render json: {status: "Error", errors: document.errors.full_messages, valid: false, message: 'error.writeFailed' }, status: 400
    end
  end

  def patch
    if codap_api_params[:recordid].present?
      document = Document.find(codap_api_params[:recordid].to_i)
    else
      render_not_found
      return
    end
    authorize! :save, document rescue (render_not_authorized && return)

    begin
      patchset = JSON.parse(request.raw_post)
      raise "Empty patchset" unless patchset && patchset.is_a?(Array)
    rescue => e
      render json: {status: "Error", errors: ["Invalid patch JSON (parsing)", e.to_s, patchset], valid: false, message: 'error.writeFailed' }, status: 400
      return
    end

    begin
      # Use JSON Patch to bring the content up-to-date
      res = JSON::Patch.new(document.content, patchset).call

      shared = res.is_a?(Hash) && res.has_key?('_permissions') && res['_permissions'].to_i == 1

      # Just using 'document.content = res; document.save' didn't seem to actually persist things, so we'll be more forceful.
      if document.update_columns({updated_at: Time.current, shared: shared}) && document.contents.update_columns({content: res, updated_at: Time.current})
        render json: {status: "Patched", valid: true, id: document.id }, status: 200
      else
        render json: {status: "Error", errors: document.errors.full_messages + document.contents.errors.full_messages, valid: false, message: 'error.writeFailed' }, status: 400
      end
    rescue => e
      render json: {status: "Error", errors: ["Invalid patch JSON (executing)", e.to_s], valid: false, message: 'error.writeFailed' }, status: 400
    end

  end

  def rename
    document = find_doc_via_params
    (render_not_found && return) unless document
    authorize! :save, document rescue (render_not_authorized && return)
    owner_id = current_user.nil? ? nil : current_user.id
    newDoc = Document.find_by(owner_id: owner_id, title: codap_api_params[:newRecordname], run_key: codap_api_params[:runKey])

    if newDoc
      # render error!
      render_duplicate_error
    else
      c = document.content
      oc = document.original_content
      c["name"] = codap_api_params[:newRecordname] if c.has_key?("name")
      oc["name"] = codap_api_params[:newRecordname] if oc && oc.has_key?("name")
      document.update_columns(title: codap_api_params[:newRecordname], updated_at: Time.now)
      document.contents.update_columns(content: c, updated_at: Time.now)
      render json: {success: true }
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

    if launch_params[:recordid] || (launch_params[:owner] && (launch_params[:recordname] || launch_params[:doc]))
      original_doc = find_doc_via_params(launch_params)
      @master_document_url = codap_link(@codap_server, original_doc) if original_doc
    elsif launch_params[:moreGames]
      moreGames = launch_params[:moreGames]
      moreGames = moreGames.to_json if moreGames.is_a?(Hash) || moreGames.is_a?(Array)
      @master_document_url = codap_link(@codap_server, moreGames)
    end

    @buttonText = launch_params[:buttonText] || 'Launch'

    @supplemental_documents = Document.where(owner_id: (current_user ? current_user.id : nil), run_key: @runKey).select{|d| d.is_codap_main_document? }

    @learner_url = Addressable::URI.parse(request.original_url)
    new_query = @learner_url.query_values || {}
    new_query["runKey"] = @runKey
    @learner_url.query_values = new_query

    @report_url = @learner_url.dup
    @report_url.path = report_path

    new_query = @report_url.query_values || {}
    new_query.delete("auth_provider")
    if current_user
      new_query["reportUser"] = current_user.username
    end
    @report_url.query_values = new_query
    @report_url = @report_url.to_s

    @learner_url = @learner_url.to_s

    authorize! :open, :url_document
    response.headers.delete 'X-Frame-Options'
    render layout: 'launch'
  end

  def report
    raise ActiveRecord::RecordNotFound.new if report_params[:runKey].blank? || report_params[:server].blank?
    authorize! :report, (current_user || :nil_user)
    @codap_server = report_params[:server]
    @runKey = report_params[:runKey]
    u = User.find_by(username: report_params[:reportUser])
    @reportUserId = u ? u.id : nil

    if report_params[:recordid] || (report_params[:owner] && (report_params[:recordname] || report_params[:doc]))
      original_doc = find_doc_via_params(report_params)
      @master_document_url = codap_link(@codap_server, original_doc) if original_doc
    elsif report_params[:moreGames]
      moreGames = report_params[:moreGames]
      moreGames = moreGames.to_json if moreGames.is_a?(Hash) || moreGames.is_a?(Array)
      @master_document_url = codap_link(@codap_server, moreGames)
    end

    @supplemental_documents = Document.where(owner_id: @reportUserId, run_key: @runKey, is_codap_main_document: true)
    @supplemental_documents = @supplemental_documents.to_a.select {|d| can? :report, d }

    response.headers.delete 'X-Frame-Options'
    render layout: 'launch'
  end

  private
    def load_index_documents
      if current_user
        if codap_api_params[:runKey]
          @documents = Document.where(owner_id: current_user.id, run_key: codap_api_params[:runKey]).order(title: :asc, run_key: :asc)
        else
          @documents = Document.where(owner_id: current_user.id).order(title: :asc, run_key: :asc)
        end
      else
        if codap_api_params[:runKey]
          @documents = Document.where(owner_id: nil, run_key: codap_api_params[:runKey]).order(title: :asc, run_key: :asc)
        else
          @documents = Document.none
        end
      end
    end

    def auto_authenticate
      if current_user
        if auth_params[:require_anonymous] ||
          (auth_params[:require_email] && auth_params[:require_email] != current_user.email && current_user.authentications.detect {|a| a.updated_at > 1.minute.ago }.nil? )
          # if we need to be running as anonymous, OR the current user doesn't match the requirements and they didn't just log in.
          sign_out current_user
        end
      end
      if current_user.nil? && auth_params[:auth_provider]
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

    def check_session_expiration
      if !current_user && flash.detect{|k,v| v =~ /session expired/}
        render json: {status: "Session Expired", valid: false, message: 'error.sessionExpired' }, status: 401
        return false
      end
      return true
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def index_params
      params.permit(:page)
    end

    def document_params
      params.require(:document).permit(:title, :content, :shared, :form_content)
    end

    def codap_api_params
      params.permit(:recordname, :recordid, :doc, :owner, :runKey, :original, :newRecordname)
    end

    def launch_params
      params.permit(:owner, :recordname, :recordid, :server, :moreGames, :doc, :runKey, :buttonText)
    end

    def report_params
      params.permit(:owner, :recordname, :recordid, :server, :moreGames, :doc, :runKey, :reportUser)
    end

    def delete_params
      params.permit(:recordname, :doc, :runKey)
    end

    def auth_params
      params.permit(:auth_provider, :require_anonymous, :require_email)
    end

    def render_not_found
      authorize! :not_found, :nil_document
      render json: {valid: false, message: "error.notFound"}, status: 404
    end

    def render_not_authorized
      authorize! :not_authorized, :nil_document
      render json: {valid: false, message: "error.permissions"}, status: 403
    end

    def render_duplicate_error
      authorize! :duplicate_error, :nil_document
      render json: {valid: false, message: "error.duplicate"}, status: 403
    end
end
