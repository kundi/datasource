Datasource.setup do |config|
  # Adapters to load
  # Available ORM adapters: activerecord, sequel
  config.adapters = [:activerecord]

  # Enable simple mode, which will always select all model database columns,
  # making Datasource easier to use. See documentation for details.
  config.simple_mode = true
end
