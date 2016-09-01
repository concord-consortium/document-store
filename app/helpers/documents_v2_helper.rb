module DocumentsV2Helper
  def codap_v2_link(codap_server, fromLaunchPage=false)
    data = {
      "documentServer" => root_url(protocol: 'https')
    }
    data["launchFromLara"] = 'true' if fromLaunchPage

    url = Addressable::URI.parse(codap_server || ENV['CODAP_DEFAULT_URL'] || 'https://codap.concord.org/releases/latest/')
    new_query = url.query_values || {}
    new_query.merge!(data)
    url.query_values = new_query
    return url.to_s
  end
end
