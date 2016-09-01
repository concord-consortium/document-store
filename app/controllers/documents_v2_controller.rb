require 'ostruct'

class DocumentsV2Controller < ApplicationController
  # don't check for csrf token
  skip_before_filter :verify_authenticity_token, :only => [:save, :patch, :create]

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
      if @document.update_columns({updated_at: Time.current}) && @document.contents.update_columns({content: patchedContent, updated_at: Time.current})
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
      copy_shared(new_doc_is_shared)
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

    @button_url = codap_v2_link(@codap_server, true)
    @button_text = launch_params[:buttonText] || 'Launch'

    @in_a_window = launch_params[:window] == 'true'

    @copy_shared_url = v2_document_create_url(source: params[:id])
    @reset_url = v2_document_save_url(id: 'RESET_ID', source: 'SOURCE_ID', accessKey: 'RW::ACCESS_KEY')  # RESET_ID, SOURCE_ID and ACCESS_KEY are replaced with the document info in the interactive state in the launch view javascript

    authorize! :open, :url_document
    response.headers.delete 'X-Frame-Options'
    render layout: 'launch'
  end

  private

  def copy_shared(new_doc_is_shared)
    render_missing_param("source") && return unless params[:source].present?

    @document = Document.find_by(id: params[:source])
    render_not_found && return unless @document

    if @document.shared
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
      render(json: {valid: false, errors: ["Source document is not shared"], message: "error.notShared"}, status: 403)
    end
  end

  def create_access_keys(document)
    # generate two unique new access keys - we can't use a unique index constraint because the keys will be null for older documents
    # giving the length of the random strings this will probably never loop
    read_access_key = nil
    read_write_access_key = nil
    loop do
      read_access_key = SecureRandom.hex(20)
      read_write_access_key = SecureRandom.hex(40)
      break if !Document.find_by(read_access_key: read_access_key) && !Document.find_by(read_write_access_key: read_write_access_key)
    end
    document.read_access_key = read_access_key
    document.read_write_access_key = read_write_access_key
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
end
