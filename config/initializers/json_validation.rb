require 'json'

class String
  attr_reader :parsed_json

  def is_json?
    begin
      @parsed_json = JSON.parse(self)
      !!@parsed_json
    rescue
      false
    end
  end
end
