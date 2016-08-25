class DocumentsController < ApplicationController
  before_filter :auto_authenticate, :only => [:launch]
  before_filter :authenticate_user!, :except => [:index, :show, :all, :open, :save, :patch, :delete, :launch, :rename, :report]
  before_filter :run_key_or_authenticate, :only => [:index, :show]
  before_filter :load_index_documents, :only => [:index, :all]
  load_and_authorize_resource
  skip_load_and_authorize_resource :only => [:all, :save, :patch, :open, :delete, :launch, :rename, :report]
  skip_before_filter :verify_authenticity_token, :only => [:save, :patch]

  before_filter :check_session_expiration, :only => [:all, :save, :patch, :open, :delete, :rename]

  after_filter :log_access, :only => [:show, :edit, :create, :update, :destroy, :open, :save, :patch, :rename, :delete]

  include DocumentsHelper

  cattr_accessor :run_key_generator
  self.run_key_generator = lambda { return SecureRandom.uuid }

  # GET /documents
  # GET /documents.json
  def index
    @documents = @documents.includes(:children).paginate(page: index_params[:page], :per_page => 20) if @documents.respond_to?('paginate')
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
    @document = find_doc_via_params
    new_doc = nil
    render_not_found && return unless @document
    content = @document.content
    if codap_api_params[:original]
      begin
        authorize! :open_original, @document
        content = @document.original_content || @document.content
      rescue
      end
    else
      authorize! :open, @document rescue (render_not_authorized && return)
    end
    if @document.owner != current_user
      content["_permissions"] = 0 if content && content.is_a?(Hash) && content.has_key?("_permissions")
      if can?(:save, :document)
        # check if a document exists with the same name for the current_user
        new_doc = Document.find_or_initialize_by(owner: current_user, title: @document.title, run_key: codap_api_params[:runKey] )
        new_doc_existed = !new_doc.new_record?
      end
    end
    response.headers['Document-Id'] = "#{@document.id}"
    response.headers['X-Codap-Opened-From-Shared-Document'] = "true" if new_doc
    response.headers['X-Codap-Will-Overwrite'] = "true" if new_doc && new_doc_existed
    render json: content
  end

  def save
    content = request.raw_post

    warn_overwrite = false
    if codap_api_params[:recordid].present?
      @document = Document.find(codap_api_params[:recordid].to_i)
      @access_params = {recordid: codap_api_params[:recordid]}
    else
      @document = Document.find_or_initialize_by(owner: current_user, title: codap_api_params[:recordname], run_key: codap_api_params[:runKey])
      @access_params = {owner: current_user ? current_user.id : nil, title: codap_api_params[:recordname], run_key: codap_api_params[:runKey]}
      warn_overwrite = !@document.new_record? && !codap_api_params[:runKey]
    end
    begin
      authorize! :save, @document
    rescue
      if @document.owner == current_user
        render_not_authorized
        return
      else
        new_doc = Document.find_or_initialize_by(owner: current_user, title: codap_api_params[:recordname] || @document.title, run_key: codap_api_params[:runKey] )
        if new_doc.new_record? || codap_api_params[:runKey]
          @document = new_doc
        else
          warn_overwrite = true
        end
      end
    end

    if warn_overwrite
      render_duplicate_error
      return
    end

    @document.form_content = content
    @document.original_content = @document.content if @document.new_record?
    @document.shared = @document.content.is_a?(Hash) && @document.content.has_key?('_permissions') && @document.content['_permissions'].to_i == 1
    @document.parent_id = codap_api_params[:parentDocumentId].to_i if codap_api_params[:parentDocumentId].present?

    if @document.save
      render json: {status: "Created", valid: true, id: @document.id }, status: :created
    else
      render json: {status: "Error", errors: @document.errors.full_messages, valid: false, message: 'error.writeFailed' }, status: 400
    end
  end

  def patch
    if codap_api_params[:recordid].present?
      @document = Document.find(codap_api_params[:recordid].to_i)
      @access_params = {recordid: codap_api_params[:recordid]}
    else
      render_not_found
      return
    end
    authorize! :save, @document rescue (render_not_authorized && return)

    begin
      patchset = JSON.parse(request.raw_post)
      raise "Empty patchset" unless patchset && patchset.is_a?(Array)
    rescue => e
      render json: {status: "Error", errors: ["Invalid patch JSON (parsing)", e.to_s, patchset], valid: false, message: 'error.writeFailed' }, status: 400
      return
    end

    begin
      # Use JSON Patch to bring the content up-to-date
      res = JSON::Patch.new(@document.content, patchset).call

      shared = res.is_a?(Hash) && res.has_key?('_permissions') && res['_permissions'].to_i == 1

      doc_updates = {updated_at: Time.current, shared: shared}
      doc_updates[:parent_id] = codap_api_params[:parentDocumentId].to_i if codap_api_params[:parentDocumentId].present?

      # Just using '@document.content = res; @document.save' didn't seem to actually persist things, so we'll be more forceful.
      if @document.update_columns(doc_updates) && @document.contents.update_columns({content: res, updated_at: Time.current})
        render json: {status: "Patched", valid: true, id: @document.id }, status: 200
      else
        render json: {status: "Error", errors: @document.errors.full_messages + @document.contents.errors.full_messages, valid: false, message: 'error.writeFailed' }, status: 400
      end
    rescue => e
      render json: {status: "Error", errors: ["Invalid patch JSON (executing)", e.to_s], valid: false, message: 'error.writeFailed' }, status: 400
    end

  end

  def rename
    @document = find_doc_via_params
    (render_not_found && return) unless @document
    authorize! :save, @document rescue (render_not_authorized && return)
    owner_id = current_user.nil? ? nil : current_user.id
    newDoc = Document.find_by(owner_id: owner_id, title: codap_api_params[:newRecordname], run_key: codap_api_params[:runKey])

    if newDoc
      # render error!
      render_duplicate_error
    else
      c = @document.content
      oc = @document.original_content
      c["name"] = codap_api_params[:newRecordname] if c.has_key?("name")
      oc["name"] = codap_api_params[:newRecordname] if oc && oc.has_key?("name")
      @document.update_columns(title: codap_api_params[:newRecordname], updated_at: Time.now)
      @document.contents.update_columns(content: c, updated_at: Time.now)
      render json: {success: true }
    end
  end

  def delete
    opts = delete_params
    opts[:owner] = current_user.username if current_user
    @document = find_doc_via_params(opts)
    (render_not_found && return) unless @document
    authorize! :destroy, @document rescue (render_not_authorized && return)
    @document.destroy
    render json: {success: true}
  end

  def launch
    @codap_server = launch_params[:server]
    @runKey = launch_params[:runKey] || self.run_key_generator.call

    if launch_params[:recordid] || (launch_params[:owner] && (launch_params[:recordname] || launch_params[:doc]))
      original_doc = find_doc_via_params(launch_params)
      @master_document_url = codap_link(@codap_server, original_doc, false, true) if original_doc
    elsif launch_params[:moreGames]
      moreGames = launch_params[:moreGames]
      moreGames = moreGames.to_json if moreGames.is_a?(Hash) || moreGames.is_a?(Array)
      @master_document_url = codap_link(@codap_server, moreGames, false, true)
    end

    @buttonText = launch_params[:buttonText] || 'Launch'

    @supplemental_documents = Document.where(owner_id: (current_user ? current_user.id : nil), run_key: @runKey).select{|d| d.is_codap_main_document? }

    @learner_url = Addressable::URI.parse(request.original_url)
    new_query = @learner_url.query_values || {}
    new_query["runKey"] = @runKey
    new_query.delete("auth_provider")
    new_query.delete("require_email")
    new_query.delete("require_anonymous")
    new_query.delete("auto_auth_in_progress")
    @learner_url.query_values = new_query

    @report_url = @learner_url.dup
    @report_url.path = report_path

    new_query = @report_url.query_values || {}
    new_query.delete("auth_provider")
    new_query.delete("require_email")
    new_query.delete("require_anonymous")
    new_query.delete("auto_auth_in_progress")
    if current_user
      new_query["reportUser"] = current_user.username
    end
    @report_url.query_values = new_query
    @report_url = @report_url.to_s

    @learner_url = @learner_url.to_s

    @auth_failed = auth_params[:auto_auth_failed] == 'true'
    @in_a_window = launch_params[:window] == 'true'

    authorize! :open, :url_document
    response.headers.delete 'X-Frame-Options'
    render layout: 'launch'
  end

  def report
    raise ActiveRecord::RecordNotFound.new if report_params[:runKey].blank? || report_params[:server].blank?

    authorize! :report, Document

    @codap_server = report_params[:server]
    @runKey = report_params[:runKey]

    users = User.where(username: report_params[:reportUser])
    num_users = users.count
    if (num_users == 0)
      @reportUserId = nil
    elsif (num_users == 1)
      @reportUserId = users.first.id
    else
      # HACK: because usernames are not unique, just passing the username is not enough to find the user.
      #  the username is taken from the authentication provider. It is common in testing to have the same
      #  username on production and staging portals. So this problem happens often in testing. We do have
      #  a runKey though, and it seems that is generally unique between portals, so it can be used to figure
      #  out the correct user.
      #
      #  A better solution would be to enforce unique runKeys for each document, and then there would be no
      #  need to lookup the user here. I think doing that would require defining the runKey only on the server
      #  currently the runKey can be set by the client when a document is created.
      unique_owner_docs = Document.select(:owner_id).where(owner_id: users.map(&:id), run_key: @runKey).group(:owner_id)
      owners = unique_owner_docs.map{|doc| doc.owner}

      if owners.count == 1
        @reportUserId = owners.first.id
      else
        # either there are no documents matching any of these users with the pass runkey
        # or there are mutliple users that have documents with the same runkey
        # if there are no documents then we fall back to initial users list, otherwise
        # we now look at just the owners of the documents.
        if owners.count > 1
          users = owners
        end

        # As a last resort for filtering out multiple users, try to filter the users based on the authentication
        # of the current_user.  When running the report the current_user will probably be the teacher. And in
        # the majority cases the teacher will only have one authentication provider, so this is a good filter.
        # However for test teachers it is very likely the teacher will have multiple authentications so in that
        # case this probably isn't going to filter very much.
        source = current_user.authentications.first.provider rescue nil
        u = users.to_a.detect {|user| !user.authentications.detect {|a| a.provider == source }.nil? }
        @reportUserId = u ? u.id : nil
      end
    end

    # It isn't entirely clear why we need to find the master document
    # The report view has different messages if we do or don't
    if report_params[:recordid] || (report_params[:owner] && (report_params[:recordname] || report_params[:doc]))
      original_doc = find_doc_via_params(report_params)
      @found_master_document = original_doc.present?
    elsif report_params[:moreGames]
      @found_master_document = true
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
          @documents = Document.where(owner_id: current_user.id, is_codap_main_document: true, run_key: codap_api_params[:runKey]).order(title: :asc, run_key: :asc)
        else
          @documents = Document.where(owner_id: current_user.id, is_codap_main_document: true).order(title: :asc, run_key: :asc)
        end
      else
        if codap_api_params[:runKey]
          @documents = Document.where(owner_id: nil, is_codap_main_document: true, run_key: codap_api_params[:runKey]).order(title: :asc, run_key: :asc)
        else
          @documents = Document.none
        end
      end
    end

    def auto_authenticate
      if current_user
        if auth_params[:require_anonymous] ||
          (auth_params[:require_email] && auth_params[:require_email] != current_user.email && auth_params[:auto_auth_in_progress].nil? )
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

              orig_url = Addressable::URI.parse(request.original_url)
              new_query = orig_url.query_values || {}
              new_query["auto_auth_in_progress"] = 'true'
              orig_url.query_values = new_query
              session[:user_return_to] = orig_url.to_s

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
      @document = nil
      if title = (p[:recordname] || p[:doc])
        if p[:owner] && !p[:owner].empty?
          owner = User.find_by(username: p[:owner])
          owner_id = owner ? owner.id : -1
        else
          owner_id = nil
        end
        if owner_id != -1
          @document = Document.find_by(owner_id: owner_id, title: title, run_key: p[:runKey])
          @access_params = {owner_id: owner_id, title: title, run_key: p[:runKey]}
          if @document.nil? && !p[:runKey].nil?
            @document = Document.find_by(owner_id: owner_id, title: title, run_key: nil)
            @access_params = {owner_id: owner_id, title: title, run_key: nil}
          end
        end
      elsif p[:recordid]
        @document = Document.includes(:owner).find(p[:recordid]) rescue nil
        @access_params = {recordid: p[:recordid]}
      end
      return @document
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
      params.permit(:recordname, :recordid, :doc, :owner, :runKey, :original, :newRecordname, :parentDocumentId)
    end

    def launch_params
      params.permit(:owner, :recordname, :recordid, :server, :moreGames, :doc, :runKey, :buttonText, :window)
    end

    def report_params
      params.permit(:owner, :recordname, :recordid, :server, :moreGames, :doc, :runKey, :reportUser)
    end

    def delete_params
      params.permit(:recordname, :doc, :runKey)
    end

    def auth_params
      params.permit(:auth_provider, :require_anonymous, :require_email, :auto_auth_in_progress, :auto_auth_failed)
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

    def log_access
      DocumentAccessLog.log(@document.id, '1', action_name, (@access_params || {id: params[:id]}).to_json) if @document
    end
end
