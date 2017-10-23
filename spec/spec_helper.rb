ENV['RAILS_ENV'] ||= 'test'

##
# Code Climate
#
if ENV['TRAVIS']
  require 'simplecov'
  SimpleCov.start
end

##
# Load Rspec supporting files
#
Dir['./spec/support/**/*.rb'].each { |f| require f }

##
# Load Rails dummy application based on gemfile name substituted by Appraisal
#
if ENV['APPRAISAL_INITIALIZED'] || ENV['TRAVIS']
  app_name = Pathname.new(ENV['BUNDLE_GEMFILE']).basename.sub('.gemfile', '')
else
  app_name = 'rails_5'
end

require File.expand_path("../../spec/app/#{app_name}/config/environment", __FILE__)

APP_RAKEFILE = File.expand_path("../../spec/app/#{app_name}/Rakefile", __FILE__)

##
# Load Rspec
#
require 'rspec/rails'
require 'pry'

# Configure
RSpec.configure do |config|
  config.fixture_path = File.join(File.dirname(__FILE__), '/fixtures')

  # Turn the deprecation warnings into errors, giving you the full backtrace
  config.raise_errors_for_deprecations!

  config.before(:suite) do
    Config.module_eval do

      # Extend Config module with ability to reset configuration to the default values
      def self.reset
        self.const_name       = 'Settings'
        self.use_env          = false
        self.knockout_prefix  = nil
        self.overwrite_arrays = true
        self.schema           = nil if RUBY_VERSION >= '2.1'
        class_variable_set(:@@_ran_once, false)
      end
    end
  end
end


##
# Print some debug info
#
puts
puts "Gemfile: #{ENV['BUNDLE_GEMFILE']}"
puts 'Rails version:'

Gem.loaded_specs.each { |name, spec|
  puts "\t#{name}-#{spec.version}" if %w{rails activesupport sqlite3 rspec-rails}.include?(name)
}

puts
