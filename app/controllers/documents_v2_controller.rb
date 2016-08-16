class DocumentsV2Controller < ApplicationController

  before_filter :require_valid_access_key, :only => [:open]
  before_filter :require_valid_read_write_access_key, :only => [:save, :patch]
  before_filter :require_valid_shared_recordid, :only => [:copy_shared]

  # don't check for csrf token
  skip_before_filter :verify_authenticity_token, :only => [:save, :patch, :copy_shared]

  # v2 of the api is all anonymous access
  skip_authorization_check

  include DocumentsV2Helper

  def open
    readOnly = params[:readAccessKey].present?
    response.headers['Document-Id'] = "#{@document.id}"
    response.headers['Allow'] = "GET, HEAD, OPTIONS#{readOnly ? '' : ', PUT, PATCH'}"
    response.headers['X-Document-Store-Read-Only'] = readOnly ? 'true' : 'false'
    render json: @document.content
  end

  def save
    @document.form_content = request.raw_post
    if @document.save
      render json: {status: "Saved", valid: true, id: @document.id }, status: 200
    else
      render json: {status: "Error", errors: @document.errors.full_messages, valid: false, message: 'error.writeFailed' }, status: 400
    end
  end

  def patch
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

  def copy_shared
    # generate two unique new access keys - we can't use a unique index constraint because the keys will be null for older documents
    # giving the length of the random strings this will probably never loop
    read_access_key = nil
    read_write_access_key = nil
    loop do
      read_access_key = SecureRandom.hex(20)
      read_write_access_key = SecureRandom.hex(40)
      break if !Document.find_by(read_access_key: read_access_key) && !Document.find_by(read_write_access_key: read_write_access_key)
    end

    copy = Document.new
    copy.title = @document.title
    copy.content = @document.content
    copy.original_content = @document.content
    copy.read_access_key = read_access_key
    copy.read_write_access_key = read_write_access_key
    copy.run_key = read_write_access_key  # the run_key needs to be set because of the title validation: "validates :title, uniqueness: {scope: [:owner, :run_key]}"
    if copy.save
      render json: {status: "Copied", valid: true, id: copy.id, readAccessKey: copy.read_access_key, readWriteAccessKey: copy.read_write_access_key}, status: 200
    else
      render json: {status: "Error", errors: copy.errors.full_messages + copy.contents.errors.full_messages, valid: false, message: 'error.writeFailed' }, status: 400
    end
  end

  private

  def required_param(param_sym)
    param_present = params[param_sym].present?
    render_missing_param(param_sym.to_s) unless param_present
    param_present
  end

  def require_valid_access_key
    if params[:readAccessKey].present?
      @document = Document.find_by(read_access_key: params[:readAccessKey])
    elsif params[:readWriteAccessKey].present?
      @document = Document.find_by(read_write_access_key: params[:readWriteAccessKey])
    else
      render_missing_param('readAccessKey or readWriteAccessKey') && return
    end
    render_not_found unless @document
  end

  def require_valid_read_write_access_key
    return unless required_param :readWriteAccessKey
    @document = Document.find_by(read_write_access_key: params[:readWriteAccessKey])
    render_not_found unless @document
  end

  def require_valid_shared_recordid
    return unless required_param :recordid
    @document = Document.find_by(id: params[:recordid])
    render_not_found unless @document
    if !@document.shared
      render json: {valid: false, errors: ["Source document is not shared"], message: "error.notShared"}, status: 403
    end
  end

  def render_missing_param(param)
    render json: {valid: false, errors: ["Missing #{param} parameter"], message: "error.missingParam"}, status: 400
  end

  def render_not_found
    render json: {valid: false, message: "error.notFound"}, status: 404
  end
end
