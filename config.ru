# This file is used by Rack-based servers to start the application.

begin
  require 'unicorn/worker_killer'
  use Unicorn::WorkerKiller::Oom, (225*(1024**2)), (256*(1024**2))

  require 'gctools/oobgc'
  use(GC::OOB::UnicornMiddleware)
rescue
end

require ::File.expand_path('../config/environment',  __FILE__)
run Rails.application
