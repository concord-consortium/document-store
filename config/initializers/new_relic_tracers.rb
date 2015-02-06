if ENV['NEW_RELIC_TRACERS_ENABLED'] =~ /true/i
  require 'new_relic/agent/method_tracer'

  DocumentsController.class_eval do
    include ::NewRelic::Agent::MethodTracer

    add_method_tracer :find_doc_via_params
    add_method_tracer :authorize!
    add_method_tracer :auto_authenticate
    add_method_tracer :authenticate_user!
    add_method_tracer :run_key_or_authenticate
    add_method_tracer :load_index_documents
    add_method_tracer :check_session_expiration
  end

  Document.class_eval do
    include ::NewRelic::Agent::MethodTracer

    add_method_tracer :form_content=
  end

  JSON.class_eval do
    class << self
      include ::NewRelic::Agent::MethodTracer

      add_method_tracer :parse, 'JSON/parse'
    end
  end

  JSON::Patch.class_eval do
    include ::NewRelic::Agent::MethodTracer

    add_method_tracer :call
  end
end
