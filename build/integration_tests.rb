#  Phusion Passenger - https://www.phusionpassenger.com/
#  Copyright (c) 2010-2014 Phusion
#
#  "Phusion Passenger" is a trademark of Hongli Lai & Ninh Bui.
#
#  See LICENSE file for license information.

### Integration tests ###

def integration_test_dependencies(runtime_target_name)
  if string_option('PASSENGER_LOCATION_CONFIGURATION_FILE')
    return []
  else
    return [runtime_target_name, NATIVE_SUPPORT_TARGET].compact
  end
end

desc "Run all integration tests"
task 'test:integration' => ['test:integration:apache2', 'test:integration:nginx'] do
end

dependencies = integration_test_dependencies(:_apache2) + ['test/support/allocate_memory']
desc "Run Apache 2 integration tests"
task 'test:integration:apache2' => dependencies do
  command = "bundle exec rspec -c -f s --tty integration_tests/apache2_tests.rb"
  if boolean_option('SUDO')
    command = "#{PlatformInfo.ruby_sudo_command} -E #{command}"
  end
  if grep = string_option('E')
    require 'shellwords'
    command << " -e #{Shellwords.escape(grep)}"
  end
  sh "cd test && exec #{command}"
end

dependencies = integration_test_dependencies(:_nginx)
desc "Run Nginx integration tests"
task 'test:integration:nginx' => dependencies do
  command = "bundle exec rspec -c -f s --tty integration_tests/nginx_tests.rb"
  if boolean_option('SUDO')
    command = "#{PlatformInfo.ruby_sudo_command} -E #{command}"
  end
  if grep = string_option('E')
    require 'shellwords'
    command << " -e #{Shellwords.escape(grep)}"
  end
  repeat = true
  while repeat
    sh "cd test && exec #{command}"
    repeat = boolean_option('REPEAT')
  end
end

dependencies = integration_test_dependencies(:_nginx)
desc "Run Passenger Standalone integration tests"
task 'test:integration:standalone' => dependencies do
  command = "bundle exec rspec -c -f s --tty integration_tests/standalone_tests.rb"
  if grep = string_option('E')
    require 'shellwords'
    command << " -e #{Shellwords.escape(grep)}"
  end
  sh "cd test && exec #{command}"
end

desc "Run native packaging tests"
task 'test:integration:native_packaging' do
  command = "bundle exec rspec -c -f s --tty integration_tests/native_packaging_spec.rb"
  if boolean_option('SUDO')
    command = "#{PlatformInfo.ruby_sudo_command} -E #{command}"
  end
  if grep = string_option('E')
    require 'shellwords'
    command << " -e #{Shellwords.escape(grep)}"
  end
  case PlatformInfo.os_name
  when "linux"
    if PlatformInfo.linux_distro_tags.include?(:debian)
      command = "env NATIVE_PACKAGING_METHOD=deb " +
        "LOCATIONS_INI=/usr/lib/ruby/vendor_ruby/phusion_passenger/locations.ini " +
        command
    elsif PlatformInfo.linux_distro_tags.include?(:redhat)
      command = "env NATIVE_PACKAGING_METHOD=rpm " +
        "LOCATIONS_INI=/usr/lib/ruby/site_ruby/1.8/phusion_passenger/locations.ini " +
        command
    else
      abort "Unsupported Linux distribution"
    end
  when "macosx"
    # The tests put /usr/bin and /usr/sbin first in PATH, causing /usr/bin/ruby to be used.
    # We should run the tests in /usr/bin/ruby too, so that native_support is compiled for
    # the same Ruby.
    prefix = "env NATIVE_PACKAGING_METHOD=homebrew " +
      "LOCATIONS_INI=/usr/local/Cellar/passenger/#{VERSION_STRING}/libexec/lib/phusion_passenger/locations.ini"
    if PlatformInfo.in_rvm?
      prefix << " rvm-exec system /usr/bin/ruby -S"
    end
    command = "#{prefix} #{command}"
  else
    abort "Unsupported operating system"
  end
  sh "cd test && exec #{command}"
end

dependencies = integration_test_dependencies(:_apache2)
desc "Run the 'apache2' integration test infinitely, and abort if/when it fails"
task 'test:restart' => dependencies do
  require 'shellwords'
  color_code_start = "\e[33m\e[44m\e[1m"
  color_code_end = "\e[0m"
  i = 1
  while true do
    puts "#{color_code_start}Test run #{i} (press Ctrl-C multiple times to abort)#{color_code_end}"
    command = "bundle exec rspec -c -f s --tty integration_tests/apache2_tests.rb"
    if grep = string_option('E')
      command << " -e #{Shellwords.escape(grep)}"
    end
    sh "cd test && exec #{command}"
    i += 1
  end
end
