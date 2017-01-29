module DocumentsV2Helper
  def codap_v2_link(codap_server)
    data = {
      "documentServer" => root_url(protocol: ENV['V2_LINK_PROTOCOL'] || 'https')
    }

    url = Addressable::URI.parse(codap_server || ENV['CODAP_DEFAULT_URL'] || 'https://codap.concord.org/releases/latest/')
    new_query = url.query_values || {}
    new_query.merge!(data)
    url.query_values = new_query
    return url.to_s
  end
end
