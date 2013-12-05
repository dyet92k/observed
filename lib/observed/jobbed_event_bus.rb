require 'thread'
require 'observed/event_bus'

module Observed
  class JobbedEventBus
    def initialize(args={})
      @bus = Observed::EventBus.new
      @receives = {}
      @job_factory = args[:job_factory] || fail("The parameter :job_factory is missing in args(#{args}")
      @mutex = ::Mutex.new
    end
    def pipe_to_emit(tag)
      @job_factory.job { |*params|
        self.emit(tag, *params)
        params
      }
    end
    def emit(tag, *params)
      @bus.emit tag, *params
    end
    def receive(pattern)
      job = @job_factory.mutable_job {|data, options|
        [data, options]
      }
      @bus.on_receive(pattern) do |*params|
        @mutex.synchronize do
          job.now(*params)
        end
      end
      job
    end
  end
end