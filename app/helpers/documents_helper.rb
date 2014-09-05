module DocumentsHelper
  def codap_link(codap_server, document)
    data = { server: URI.encode_www_form_component(root_url).gsub("+", "%20"), :runKey => @runKey }
    if document.is_a?(Document)
      data[:doc] = URI.encode_www_form_component(document.title).gsub("+", "%20")
      data[:owner] = (URI.encode_www_form_component(document.owner.username).gsub("+", "%20") rescue '')
      codap_query = '?documentServer=%{server}&doc=%{doc}&owner=%{owner}&runKey=%{runKey}' % data
    else
      data[:moreGames] = URI.encode_www_form_component(document).gsub("+", "%20")
      codap_query = '?documentServer=%{server}&moreGames=%{moreGames}&runKey=%{runKey}' % data
    end
    URI.parse(codap_server).merge(codap_query).to_s
  end
end
