require "addressable/template"
module Features
  module UrlHelpers

    def report_url(query_hash)
      return _report_url_template.expand(query: query_hash).to_s
    end

    def report_path(query_hash)
      return _report_path_template.expand(query: query_hash).to_s
    end

    def launch_url(query_hash)
      return _launch_url_template.expand(query: query_hash).to_s
    end

    def launch_path(query_hash)
      return _launch_path_template.expand(query: query_hash).to_s
    end

    def doc_url(base, query_hash)
      uri = Addressable::URI.parse(base)
      query_hash[:runAsGuest] = 'true'
      uri.query_values = (uri.query_values(Hash) || {}).merge(query_hash)
      uri.to_s
    end

    private

    def _report_path_template
      return @_report_path_template || @_report_path_template = Addressable::Template.new("/document/report{?query*}")
    end

    def _report_url_template
      return @_report_path_template || @_report_path_template = Addressable::Template.new("http://www.example.com/document/report{?query*}")
    end

    def _launch_path_template
      return @_launch_path_template || @_launch_path_template = Addressable::Template.new("/document/launch{?query*}")
    end

    def _launch_url_template
      return @_launch_path_template || @_launch_path_template = Addressable::Template.new("http://www.example.com/document/launch{?query*}")
    end
  end
end
