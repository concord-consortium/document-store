module DocumentsHelper
  def codap_link(codap_server, document)
    data = {
      "documentServer" => root_url
    }
    rkey = (@runKey || document.run_key)
    data["runKey"] = rkey if rkey
    if document.is_a?(Document)
      data["recordid"] = document.id
    else
      data["moreGames"] = document
    end

    url = Addressable::URI.parse(codap_server || ENV['CODAP_DEFAULT_URL'] || 'http://codap.concord.org/releases/latest/')
    new_query = url.query_values || {}
    new_query.merge!(data)
    url.query_values = new_query
    return url.to_s
  end
end
