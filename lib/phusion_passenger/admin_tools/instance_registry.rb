# encoding: utf-8
#  Phusion Passenger - https://www.phusionpassenger.com/
#  Copyright (c) 2014 Phusion
#
#  "Phusion Passenger" is a trademark of Hongli Lai & Ninh Bui.
#
#  See LICENSE file for license information.

require 'fileutils'
PhusionPassenger.require_passenger_lib 'admin_tools/instance'

module PhusionPassenger
  module AdminTools

    class InstanceRegistry
      def initialize(path = nil)
        @path = path || default_path
      end

      def list(options = {})
        options = {
          :clean_stale_or_corrupted => true
        }.merge(options)
        instances = []

        Dir["#{@path}/passenger.*"].each do |dir|
          instance = Instance.new(dir)
          case instance.state
          when :good
            if instance.locked?
              instances << instance
            elsif options[:clean_stale_or_corrupted]
              cleanup(dir)
            end
          when :structure_version_unsupported
            next
          when :corrupted
            if !instance.locked? && options[:clean_stale_or_corrupted]
              cleanup(dir)
            end
          when :not_finalized
            if instance.stale? && options[:clean_stale_or_corrupted]
              cleanup(dir)
            end
          end
        end
        return instances
      end

      def find_by_name(name, options = {})
        return list(options).find { |instance| instance.name == name }
      end

      def find_by_name_prefix(name, options = {})
        prefix = /^#{Regexp.escape name}/
        results = list(options).find_all { |instance| instance.name =~ prefix }
        if results.size <= 1
          return results.first
        else
          return :ambiguous
        end
      end

    private
      def default_path
        ["PASSENGER_INSTANCE_REGISTRY_DIR", "TMPDIR"].each do |name|
          if ENV.has_key?(name) && !ENV[name].empty?
            return ENV[name]
          end
        end
        return "/tmp"
      end

      def cleanup(path)
        puts "*** Cleaning stale instance directory #{path}"
        FileUtils.chmod_R(0700, path) rescue nil
        FileUtils.remove_entry_secure(path)
      end
    end

  end # module AdminTools
end # module PhusionPassenger
