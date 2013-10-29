require 'observed/configurable'
require 'logger'

module Observed
  module OutputHelpers
    module Average

      include Observed::Configurable

      class << self

        def included(klass)
          klass.instance_eval do
            attribute :elapsed_time_pattern, :default => /(\d+) milliseconds/
            attribute :format, :default => ->(avg) { "#{avg}"}

            # !@attribute [r] time_window
            #   @return [Float] The period within which data to calculate averages are collected
            attribute :time_window

            attribute :tag
          end
        end

      end

      def emit(tag, time, data)
        md = data.match(elapsed_time_pattern)
        unless md
          logger.debug "Encountered not-matching data: #{data} for the tag '#{tag}'"
        end
        elapsed_time = md[1].to_f
        now = self.now
        if elapsed_time.zero?
          logger.debug "`elapsed_time` is zero. Possibly a bug? In: matched by the pattern #{elapsed_time_pattern} against the data #{data}"
        end
        histogram[time] = elapsed_time

        portion = histogram.reject { |time, data|
          expired = time < now - time_window
          expired
        }
        if (portion.size > 0)
          sum = portion.values.inject(0.0) { |sum, t| sum + t }
          avg = sum / portion.size
          logger.debug "Emitting #{avg}"
          system.emit(self.tag, now, format.call(avg))
        else
          logger.debug "Skipping emit since no data exist within the period from #{now - time_window} until #{now}."
        end
      end

      private

      def logger
        Logger.new(STDOUT)
      end

      def histogram
        @times ||= {}
      end

    end
  end
end