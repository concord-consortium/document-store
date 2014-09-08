module DocumentsHelper
  def codap_link(codap_server, document)
    data = {
      "documentServer" => root_url,
      "runKey" => @runKey
    }
    if document.is_a?(Document)
      data["doc"] = document.title
      data["owner"] = document.owner.username if document.owner
    else
      data["moreGames"] = document
    end

    url = Addressable::URI.parse(codap_server)
    new_query = url.query_values || {}
    new_query.merge!(data)
    url.query_values = new_query
    return url.to_s
  end
end
