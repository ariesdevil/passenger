#  Phusion Passenger - https://www.phusionpassenger.com/
#  Copyright (c) 2014 Phusion
#
#  "Phusion Passenger" is a trademark of Hongli Lai & Ninh Bui.
#
#  See LICENSE file for license information.

require 'optparse'
PhusionPassenger.require_passenger_lib 'constants'
PhusionPassenger.require_passenger_lib 'config/command'
PhusionPassenger.require_passenger_lib 'config/nginx_engine_compiler'
PhusionPassenger.require_passenger_lib 'utils/ansi_colors'

module PhusionPassenger
  module Config

    class CompileNginxEngineCommand < Command
      include InstallationUtils

      def run
        @options = { :colorize => :auto, :force_tip => true }
        parse_options
        initialize_objects
        sanity_check
        if !NginxEngineCompiler.new(@options).run
          abort
        end
      end

    private
      def self.create_option_parser(options)
        OptionParser.new do |opts|
          nl = "\n" + ' ' * 37
          opts.banner = "Usage: passenger-config compile-nginx-engine [OPTIONS]\n"
          opts.separator ""
          opts.separator "  Compile an Nginx engine, for use in #{PROGRAM_NAME} Standalone."
          opts.separator ""

          opts.separator "Options:"
          opts.on("--working-dir PATH", String, "Store temporary files in the given#{nl}" +
            "directory, instead of creating one") do |val|
            options[:working_dir] = val
          end
          opts.on("--nginx-version VERSION", String, "Nginx version to compile. " +
            "Default: #{PREFERRED_NGINX_VERSION}") do |val|
            options[:nginx_version] = val
          end
          opts.on("--nginx-tarball PATH", String, "Use the given Nginx tarball instead of#{nl}" +
            "downloading it. You MUST also specify the#{nl}" +
            "Nginx version with --nginx-version") do |val|
            options[:nginx_tarball] = val
          end
          opts.on("-f", "--force", "Skip sanity checks") do
            options[:force] = true
          end
          opts.on("--no-force-tip", "Do not print any tips regarding the --force parameter") do
            options[:force_tip] = false
          end
          opts.on("-h", "--help", "Show this help") do
            options[:help] = true
          end
        end
      end

      def help
        puts @parser
      end

      def initialize_objects
        @colors = Utils::AnsiColors.new(@options[:colorize])
        if !@options[:nginx_version]
          if @options[:nginx_tarball]
            abort "#{@colors.red}Error: if you specify --nginx-tarball, " +
              "you must also specify --nginx-version.#{@colors.reset}"
          else
            @options[:nginx_version] = PREFERRED_NGINX_VERSION
          end
        end
      end

      def sanity_check
        return if @options[:force]

        if PhusionPassenger.find_support_binary("nginx-#{@options[:nginx_version]}")
          puts "#{@colors.green}The Nginx engine (version #{@options[:nginx_version]}) " +
            "is already installed.#{@colors.reset}"
          if @options[:force_tip]
            puts "If you want to recompile it, re-run this program with the --force parameter."
          end
          exit
        end
      end
    end

  end # module Config
end # module PhusionPassenger
