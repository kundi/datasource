ENV["RAILS_ENV"] ||= 'test'
require 'rspec/core'
require 'rspec/expectations'
require 'rspec/mocks'
require 'database_cleaner'
require 'pry'

require 'active_support/all'
require 'active_record'
require 'sequel'
require 'datasource'

Datasource.setup do |config|
  config.adapters = [:activerecord, :sequel]
  config.raise_error_on_unknown_attribute_select = true
end

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.order = "random"

  config.filter_run_including focus: true
  config.run_all_when_everything_filtered = true

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before :each do
    DatabaseCleaner.start
  end

  config.after :each do
    DatabaseCleaner.clean
  end

  config.before(:example, without_raise_error_on_unknown_attribute_select: true) do
    Datasource.config.raise_error_on_unknown_attribute_select = false
  end

  config.after(:example, without_raise_error_on_unknown_attribute_select: true) do
    Datasource.config.raise_error_on_unknown_attribute_select = true
  end
end
