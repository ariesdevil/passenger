# encoding: binary
#  Phusion Passenger - https://www.phusionpassenger.com/
#  Copyright (c) 2012-2014 Phusion
#
#  "Phusion Passenger" is a trademark of Hongli Lai & Ninh Bui.
#
#  See LICENSE file for license information.

require 'thread'

module PhusionPassenger
  module Rack

    class OutOfBandGc
      # Usage:
      #
      #   OutOfBandGc.new(app, frequency, logger = nil)
      #   OutOfBandGc.new(app, options = {})
      def initialize(app, *args)
        @app = app
        if args.size == 0 || (args.size == 1 && args[0].is_a?(Hash))
          # OutOfBandGc.new(app, options = {})
          initialize_with_options(args[0] || {})
        else
          # OutOfBandGc.new(app, frequency, logger = nil)
          initialize_legacy(*args)
        end
      end

      def call(env)
        status, headers, body = @app.call(env)

        case @strategy
        when :counting
          @mutex.synchronize do
            @request_count += 1
            if @request_count == @frequency
              @request_count = 0
              headers['!~Request-OOB-Work'] = 'true'
            end
          end

        when :gctools_oobgc
          if GC::OOB.dry_run
            headers['!~Request-OOB-Work'] = 'true'
          end

        else
          raise "Unrecognized Out-Of-Band GC strategy #{@strategy.inspect}"
        end

        [status, headers, body]
      end

    private
      def initialize_with_options(options)
        @strategy = options[:strategy]
        @logger   = options[:logger]

        case @strategy
        when :counting
          @frequency     = options[:frequency]
          @request_count = 0
          @mutex         = Mutex.new
          if !@frequency || @frequency < 1
            raise ArgumentError, "The :frequency option must be a number that is at least 1."
          end
          ::PhusionPassenger.on_event(:oob_work) do
            t0 = Time.now
            disabled = GC.enable
            GC.start
            GC.disable if disabled
            @logger.info "Out Of Band GC finished in #{Time.now - t0} sec" if @logger
          end

        when :gctools_oobgc
          if !defined?(::GC::OOB)
            raise "To use the :gctools_oobgc strategy, " +
              "first add 'gem \"gctools\"' to your Gemfile, " +
              "then call 'require \"gctools/oobgc\"' and 'GC::OOB.setup' " +
              "before using the #{self.class.name} middleware."
          elsif !::GC::OOB.respond_to?(:dry_run)
            raise "To use the :gctools_oobgc strategy, you must use a sufficiently " +
              "recent version of the gctools gem. Please see this pull request: " +
              "https://github.com/tmm1/gctools/pull/5"
          elsif PhusionPassenger::App.options["spawn_method"] =~ /smart/
            # Using GC::OOB with 'smart' currently results in a segfault.
            raise "The :gctools_oobgc strategy cannot be used with the '" +
              PhusionPassenger::App.options["spawn_method"] + "' spawning method. " +
              "Please use 'direct'."
          end

          ::PhusionPassenger.on_event(:oob_work) do
            t0 = Time.now
            GC::OOB.run
            @logger.info "Out Of Band GC finished in #{Time.now - t0} sec" if @logger
          end

        when nil
          raise ArgumentError, "You must specify an Out-Of-Band GC strategy with the :strategy option."

        else
          raise ArgumentError, "Invalid Out-Of-Band GC strategy #{@strategy.inspect}"
        end
      end

      def initialize_legacy(frequency, logger = nil)
        initialize_with_options(
          :strategy => :counting,
          :frequency => frequency,
          :logger => logger)
      end
    end

  end # module Rack
end # module PhusionPassenger
