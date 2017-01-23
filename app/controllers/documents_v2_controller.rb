require 'ostruct'

class DocumentsV2Controller < ApplicationController
  # don't check for csrf token
  skip_before_filter :verify_authenticity_token, :only => [:save, :patch, :create, :create_keys]

  # v2 of the api is all anonymous access
  skip_authorization_check

  after_filter :log_access, :only => [:open, :save, :patch, :copy_shared]

  include DocumentsV2Helper

  def open
    @document = Document.find_by(id: params[:id])
    render_not_found && return unless @document

    access_key = parse_access_key

    # If an access key is present it must be checked. Shared documents without access keys are ok, unshared documents need to have a valid access key of either type.
    if access_key || !@document.shared
      render_missing_param("accessKey") && return unless access_key
      render_invalid_access_key_format && return unless access_key.valid_format?
      render_invalid_access_key && return unless valid_document_access_key(access_key)
    end

    read_only = !access_key || access_key.read_only?
    response.headers['Allow'] = "GET, HEAD, OPTIONS#{read_only ? '' : ', PUT, PATCH'}"
    render json: @document.content
  end

  def save
    @document = Document.find_by(id: params[:id])
    render_not_found && return unless @document

    return unless require_valid_read_write_access_key

    if params[:reset].present?
      @document.content = @document.original_content
    elsif params[:source].present?
      source_document = Document.find_by(id: params[:source])
      if !source_document
        render json: {status: "Error", errors: ['Source document not found'], valid: false, message: 'error.writeFailed' }, status: 400
        return
      elsif !source_document.shared
        render json: {status: "Error", errors: ['Source document is not a shared document'], valid: false, message: 'error.writeFailed' }, status: 400
        return
      end
      @document.content = source_document.content
    else
      @document.form_content = request.raw_post
    end

    @document.shared = shared_param_value() if params[:shared].present?

    if @document.save
      render json: {status: "Saved", valid: true, id: @document.id }, status: 200
    else
      render json: {status: "Error", errors: @document.errors.full_messages, valid: false, message: 'error.writeFailed' }, status: 400
    end
  end

  def patch
    @document = Document.find_by(id: params[:id])
    render_not_found && return unless @document

    return unless require_valid_read_write_access_key

    begin
      patchset = JSON.parse(request.raw_post)
      raise "Empty patchset" unless patchset && patchset.is_a?(Array)
    rescue => e
      render json: {status: "Error", errors: ["Invalid patch JSON (parsing)", e.to_s, patchset], valid: false, message: 'error.writeFailed' }, status: 400
      return
    end

    begin
      patchedContent = JSON::Patch.new(@document.content, patchset).call
      doc_updates = {updated_at: Time.current}
      doc_updates[:shared] = shared_param_value() if params[:shared].present?
      if @document.update_columns(doc_updates) && @document.contents.update_columns({content: patchedContent, updated_at: Time.current})
        render json: {status: "Patched", valid: true, id: @document.id}, status: 200
      else
        render json: {status: "Error", errors: @document.errors.full_messages + @document.contents.errors.full_messages, valid: false, message: 'error.writeFailed' }, status: 400
      end
    rescue => e
      render json: {status: "Error", errors: ["Invalid patch JSON (executing)", e.to_s], valid: false, message: 'error.writeFailed' }, status: 400
    end
  end

  def create
    new_doc_is_shared = params[:shared].present? ? params[:shared] == 'true' : false

    if params[:source].present?
      @document = Document.find_by(id: params[:source])
      render_not_found && return unless @document

      if !@document.shared
        if params[:accessKey].present?
          access_key = parse_access_key
          render_invalid_access_key_format && return unless access_key.valid_format?
          # both read-only or read-write access keys are acceptable so no need to check the type
          render_invalid_access_key && return unless valid_document_access_key(access_key)
        else
          render(json: {valid: false, errors: ["Source document is not shared and no accessKey parameter is present."], message: "error.notShared"}, status: 403) && return
        end
      end

      copy = Document.new
      copy.title = @document.title
      copy.content = @document.content
      copy.original_content = @document.content
      copy.shared = new_doc_is_shared
      copy.owner = nil
      create_access_keys(copy)
      if copy.save
        render json: {status: "Copied", valid: true, id: copy.id, readAccessKey: copy.read_access_key, readWriteAccessKey: copy.read_write_access_key}, status: 201
      else
        render json: {status: "Error", errors: copy.errors.full_messages + copy.contents.errors.full_messages, valid: false, message: 'error.writeFailed' }, status: 400
      end
    else
      @document = Document.new
      @document.form_content = request.raw_post
      @document.original_content = @document.content
      @document.shared = new_doc_is_shared
      @document.owner = nil
      create_access_keys(@document)
      if @document.save
        render json: {status: "Created", valid: true, id: @document.id, readAccessKey: @document.read_access_key, readWriteAccessKey: @document.read_write_access_key}, status: 201
      else
        render json: {status: "Error", errors: @document.errors.full_messages + @document.contents.errors.full_messages, valid: false, message: 'error.writeFailed' }, status: 400
      end
    end
  end

  def launch
    @document = Document.find_by(id: params[:id])
    @codap_server = launch_params[:server]

    @button_url = codap_v2_link(@codap_server)
    @button_text = launch_params[:buttonText] || 'Launch'

    @in_a_window = launch_params[:window] == 'true'

    @copy_shared_url = v2_document_create_url(source: params[:id])
    @reset_url = v2_document_save_url(id: 'RESET_ID', source: params[:id], accessKey: 'RW::ACCESS_KEY')  # RESET_ID and ACCESS_KEY are replaced with the document info in the interactive state in the launch view javascript

    authorize! :open, :url_document
    response.headers.delete 'X-Frame-Options'
    render layout: 'launch'
  end

  def autolaunch
    @document = Document.find_by(id: params[:id])
    @codap_server = launch_params[:server]

    @launch_url = codap_v2_link(@codap_server)

    authorize! :open, :url_document
    response.headers.delete 'X-Frame-Options'
    render layout: 'launch'
  end

  # This action is only necessary to help migrate LARA documents from the V1 API to the V2 API
  # Once this migration is complete this method should be removed
  def create_keys
    render_missing_param("api_secret") && return unless params[:api_secret].present?
    render_missing_param("docs") && return unless params[:docs].present?
    render(json: {status: "Error", errors: ['V2_API_SECRET environment variable is not set'], valid: false, message: 'error.createKeysFailed' }, status: 500) && return if ENV['V2_API_SECRET'].nil?
    render(json: {status: "Error", errors: ['api_secret parameter is incorrect'], valid: false, message: 'error.createKeysFailed' }, status: 400) && return if ENV['V2_API_SECRET'] != params[:api_secret]

    results = []
    params[:docs].each do |doc|
      # find the doc based on the params (adapted from DocumentsController#find_doc_via_params)
      document = nil
      queries = []
      owner_id = -1
      username = (doc[:owner] || doc[:reportUser])
      if username
        owner = User.find_by(username: username)
        queries.push "User: username: #{username}"
        owner_id = owner ? owner.id : -1
      end

      title = (doc[:recordname] || doc[:doc])
      if title && (owner_id != -1)
        document = Document.find_by(owner_id: owner_id, title: title, run_key: doc[:runKey])
        queries.push ["Document: owner_id: #{owner_id}", "title: #{title}", "run_key: #{doc[:runKey]}"].join(', ')
        if document.nil? && !doc[:runKey].nil?
          document = Document.find_by(owner_id: owner_id, title: title, run_key: nil)
          queries.push ["Document: owner_id: #{owner_id}", "title: #{title}", "run_key: nil"].join(', ')
        end
      end

      if !document && doc[:runKey]
        if owner_id != -1
          document = Document.find_by(owner_id: owner_id, run_key: doc[:runKey])
          queries.push ["Document: owner_id: #{owner_id}", "run_key: #{doc[:runKey]}"].join(', ')
        end
        if !document
          document = Document.find_by(run_key: doc[:runKey])
          queries.push ["Document: run_key: #{doc[:runKey]}"].join(', ')
        end
      end

      if document && (document.read_access_key.nil? || document.read_write_access_key.nil?)
        create_access_keys(document)
        document.save
      end

      if document
        result = {irs_id: doc[:irs_id], debug: {request_params: doc, queries: queries.join(' / ')}, document: {id: document.id, readAccessKey: document.read_access_key, readWriteAccessKey: document.read_write_access_key}}
      else
        result = {irs_id: doc[:irs_id], debug: {request_params: doc, queries: queries.join(' / ')}, document: nil}
      end
      results.push result
    end

    render json: {valid: true, docs: results}
  end

  private

  def create_access_keys(document)
    document.create_access_keys()
  end

  def render_missing_param(param)
    render json: {valid: false, errors: ["Missing #{param} parameter"], message: "error.missingParam"}, status: 400
  end

  def render_not_found
    render json: {valid: false, message: "error.notFound"}, status: 404
  end

  def render_invalid_access_key_format
    render json: {valid: false, errors: ["Invalid accessKey format"], message: "error.invalidAccessKeyFormat"}, status: 400
  end

  def render_invalid_access_key_type
    render json: {valid: false, errors: ["Invalid accessKey type"], message: "error.invalidAccessKeyType"}, status: 400
  end

  def render_invalid_access_key
    render json: {valid: false, errors: ["Invalid accessKey"], message: "error.invalidAccessKey"}, status: 400
  end

  def parse_access_key
    if params[:accessKey].present?
      type, key = params[:accessKey].split('::')
      return OpenStruct.new({key: key, read_only?: type == 'RO', read_write?: type == 'RW', valid_format?: ((type == 'RO') || (type == 'RW')) && (key != nil)})
    else
      return nil
    end
  end

  def valid_document_access_key(access_key, document=nil)
    document = document || @document
    if access_key.read_only?
      document.read_access_key == access_key.key
    elsif access_key.read_write?
      document.read_write_access_key == access_key.key
    else
      false
    end
  end

  def require_valid_read_write_access_key
    access_key = parse_access_key
    render_missing_param("accessKey") && return unless access_key
    render_invalid_access_key_format && return unless access_key.valid_format?
    render_invalid_access_key_type && return unless access_key.read_write?
    render_invalid_access_key && return unless valid_document_access_key(access_key)
    access_key
  end

  def log_access
    DocumentAccessLog.log(@document.id, '2', action_name, {id: params[:id]}.to_json) if @document
  end

  def launch_params
    params.permit(:owner, :server, :doc, :buttonText, :window)
  end

  def shared_param_value
    ['true', true, '1', 1].include? params[:shared]
  end

end
