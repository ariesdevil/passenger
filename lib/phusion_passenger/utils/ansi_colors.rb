#  Phusion Passenger - https://www.phusionpassenger.com/
#  Copyright (c) 2010-2014 Phusion
#
#  "Phusion Passenger" is a trademark of Hongli Lai & Ninh Bui.
#
#  See LICENSE file for license information.

module PhusionPassenger
  module Utils

    module AnsiColors
      RESET    = "\e[0m".freeze
      BOLD     = "\e[1m".freeze
      DGRAY    = "\e[90m".freeze
      RED      = "\e[31m".freeze
      ORANGE   = "\e[38;5;214m".freeze
      GREEN    = "\e[32m".freeze
      YELLOW   = "\e[33m".freeze
      WHITE    = "\e[37m".freeze
      BLACK_BG = "\e[40m".freeze
      BLUE_BG  = "\e[44m".freeze
      DEFAULT_TERMINAL_COLOR = "#{RESET}#{WHITE}#{BLACK_BG}".freeze

      extend self  # Make methods available as class methods.

      def self.new(type = :auto)
        return AnsiColorsPrinter.new(type)
      end

      def self.included(klass)
        # When included into another class, make sure that Utils
        # methods are made private.
        public_instance_methods(false).each do |method_name|
          klass.send(:private, method_name)
        end
      end

      def ansi_colorize(text)
        text = text.gsub(%r{<b>(.*?)</b>}m, "#{BOLD}\\1#{DEFAULT_TERMINAL_COLOR}")
        text.gsub!(%r{<dgray>(.*?)</dgray>}m, "#{BOLD}#{DGRAY}\\1#{DEFAULT_TERMINAL_COLOR}")
        text.gsub!(%r{<red>(.*?)</red>}m, "#{BOLD}#{RED}\\1#{DEFAULT_TERMINAL_COLOR}")
        text.gsub!(%r{<orange>(.*?)</orange>}m, "#{BOLD}#{ORANGE}\\1#{DEFAULT_TERMINAL_COLOR}")
        text.gsub!(%r{<green>(.*?)</green>}m, "#{BOLD}#{GREEN}\\1#{DEFAULT_TERMINAL_COLOR}")
        text.gsub!(%r{<yellow>(.*?)</yellow>}m, "#{BOLD}#{YELLOW}\\1#{DEFAULT_TERMINAL_COLOR}")
        text.gsub!(%r{<banner>(.*?)</banner>}m, "#{BOLD}#{BLUE_BG}#{YELLOW}\\1#{DEFAULT_TERMINAL_COLOR}")
        return text
      end

      def strip_color_tags(text)
        text = text.gsub(%r{<b>(.*?)</b>}m, "\\1")
        text = text.gsub(%r{<dgray>(.*?)</dgray>}m, "\\1")
        text.gsub!(%r{<red>(.*?)</red>}m, "\\1")
        text.gsub!(%r{<orange>(.*?)</orange>}m, "\\1")
        text.gsub!(%r{<green>(.*?)</green>}m, "\\1")
        text.gsub!(%r{<yellow>(.*?)</yellow>}m, "\\1")
        text.gsub!(%r{<banner>(.*?)</banner>}m, "\\1")
        return text
      end
    end

    class AnsiColorsPrinter
      def initialize(enabled = :auto)
        @enabled = enabled
      end

      def reset
        return maybe_colorize(AnsiColors::RESET)
      end

      def bold
        return maybe_colorize(AnsiColors::BOLD)
      end

      def dgray
        return maybe_colorize(AnsiColors::DGRAY)
      end

      def red
        return maybe_colorize(AnsiColors::RED)
      end

      def orange
        return maybe_colorize(AnsiColors::ORANGE)
      end

      def green
        return maybe_colorize(AnsiColors::GREEN)
      end

      def yellow
        return maybe_colorize(AnsiColors::YELLOW)
      end

      def white
        return maybe_colorize(AnsiColors::WHITE)
      end

      def black_bg
        return maybe_colorize(AnsiColors::BLACK_BG)
      end

      def blue_bg
        return maybe_colorize(AnsiColors::BLUE_BG)
      end

      def default_terminal_color
        return maybe_colorize(AnsiColors::DEFAULT_TERMINAL_COLOR)
      end

      def ansi_colorize(text)
        if should_output_color?
          return AnsiColors.ansi_colorize(text)
        else
          return AnsiColors.strip_color_tags(text)
        end
      end

    private
      def maybe_colorize(ansi_color)
        if should_output_color?
          return ansi_color
        else
          return ""
        end
      end

      def should_output_color?
        if @enabled == :auto
          return STDOUT.tty?
        else
          return @enabled
        end
      end
    end

  end # module Utils
end # module PhusionPassenger
