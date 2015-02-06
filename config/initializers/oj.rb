Oj.default_options = {:mode => :compat }

class OjEncoder
  attr_reader :options

  def initialize(options = nil)
    @options = options || {}
  end

  # Encode the given object into a JSON string
  def encode(value)
    Oj.dump(value)
  end
end

ActiveSupport::JSON::Encoding.json_encoder = OjEncoder
