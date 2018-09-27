class ExamplesController < ApplicationController
  skip_authorization_check

  def show
    render layout: 'example', template: "examples/#{params[:example]}"
  end
end
