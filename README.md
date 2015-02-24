# Datasource

**Please see gem [active_loaders](https://github.com/kundi/active_loaders)
documentation for now, it includes all the necessary information**

Documentation for datasource will be updated later. Active Model Serializer support
was extracted into the active_loaders gem.

#### Install

Requires Ruby 2.0 or higher.

Add to Gemfile (recommended to use github version until API is stable)

```
gem 'datasource', github: 'kundi/datasource'
```

```
bundle install
rails g datasource:install
```

#### Upgrade

```
rails g datasource:install
```

#### ORM support

- ActiveRecord
- Sequel

### Debugging and logging

Datasource outputs some useful logs that you can use debugging. By default the log level is
set to warnings only, but you can change it. You can add the following line to your
`config/initializers/datasource.rb`:

```ruby
Datasource.logger.level = Logger::INFO unless Rails.env.production?
```

You can also set it to `DEBUG` for more output. The logger outputs to `stdout` by default. It
is not recommended to have this enabled in production (simply for performance reasons).

## Getting Help

If you find a bug, please report an [Issue](https://github.com/kundi/datasource/issues/new).

If you have a question, you can also open an Issue.

## Contributing

1. Fork it ( https://github.com/kundi/datasource/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
