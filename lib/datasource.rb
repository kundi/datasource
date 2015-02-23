require 'datasource/configuration'
module Datasource
  mattr_accessor :logger

  Error = Class.new(StandardError)
  RecursionError = Class.new(StandardError)
  include Configuration

  AdapterPaths = {
    activerecord: 'datasource/adapters/active_record',
    active_record: :activerecord,
    sequel: 'datasource/adapters/sequel'
  }

module_function
  def setup
    self.logger ||= Logger.new(STDOUT).tap do |logger|
      logger.level = Logger::WARN
      logger.formatter = proc do |severity, datetime, progname, msg|
        "[Datasource][#{severity}] - #{msg}\n"
      end
      logger
    end

    yield(config)

    config.adapters.each do |adapter_name|
      adapter_path = AdapterPaths[adapter_name]
      adapter_path = AdapterPaths[adapter_path] if adapter_path.is_a?(Symbol)
      fail "Unknown Datasource adapter '#{adapter_name}'." unless adapter_path
      require adapter_path
    end
  end

  def orm_adapters
    @orm_adapters ||= begin
      Datasource::Adapters.constants.map { |name| Datasource::Adapters.const_get(name) }
    end
  end
end

require 'datasource/collection_context'
require 'datasource/base'

require 'datasource/attributes/computed_attribute'
require 'datasource/attributes/query_attribute'
require 'datasource/attributes/loaded'
