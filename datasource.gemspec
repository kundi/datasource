Gem::Specification.new do |s|
  s.name               = "datasource"
  s.version            = "0.1.1"

  s.authors            = ["Jan Berdajs"]
  s.email              = ["mrbrdo@gmail.com"]
  s.homepage           = "https://github.com/kundi/datasource"
  s.files              = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files         = Dir["test/**/*"]
  s.require_paths      = ["lib"]
  s.summary            = %q{Ruby library to automatically preload data for your serializers}
  s.license            = "MIT"

  s.add_dependency 'active_model_serializers', '>= 0.8'
  s.add_dependency 'activesupport', '>= 4.0'
  s.add_development_dependency 'rspec', '~> 3.1'
  s.add_development_dependency 'sqlite3', '~> 1.3'
  s.add_development_dependency 'activerecord', '~> 4'
  s.add_development_dependency 'pry', '~> 0.9'
  s.add_development_dependency 'sequel', '~> 4.17'
  s.add_development_dependency 'database_cleaner', '~> 1.3'
end

