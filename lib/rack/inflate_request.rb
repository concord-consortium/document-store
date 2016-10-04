# Copied from gist: https://gist.github.com/zerobearing2/e935a557a5584aaaef19

module Rack

  #
  # Inflate/ungzip request body
  #
  class InflateRequest
    def initialize(app)
      @app = app
    end

    def method_handled?(env)
      !!(env['REQUEST_METHOD'] =~ /(POST|PUT|PATCH)/)
    end

    def encoding_handled?(env)
      ['gzip', 'deflate'].include? env['HTTP_CONTENT_ENCODING']
    end

    def call(env)
      if method_handled?(env) && encoding_handled?(env)
        extracted                         = decode(env['rack.input'], env['HTTP_CONTENT_ENCODING'])
        env['X_REQUEST_CONTENT_ENCODING'] = env.delete('HTTP_CONTENT_ENCODING')
        env['CONTENT_LENGTH']             = extracted.bytesize
        env['rack.input']                 = StringIO.new(extracted)
      end
      @app.call(env)
    end

    def decode(input, content_encoding)
      case content_encoding
        when 'gzip' then Zlib::GzipReader.new(input).read
        when 'deflate' then Zlib::Inflate.inflate(input.read)
      end
    end
  end

end
