module DocumentsHelper
  def codap_link(codap_server, document, runAsGuest=false)
    data = {
      "documentServer" => root_url(protocol: 'https')
    }
    rkey = (@runKey || document.run_key)
    data["runKey"] = rkey if rkey
    if document.is_a?(Document)
      data["recordid"] = document.id
    else
      data["moreGames"] = document
    end
    data["runAsGuest"] = 'true' if runAsGuest

    url = Addressable::URI.parse(codap_server || ENV['CODAP_DEFAULT_URL'] || 'https://codap.concord.org/releases/latest/')
    new_query = url.query_values || {}
    new_query.merge!(data)
    url.query_values = new_query
    return url.to_s
  end
end
