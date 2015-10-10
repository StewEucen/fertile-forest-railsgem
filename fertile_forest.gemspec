$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "fertile_forest/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "fertile_forest"
  s.version     = FertileForest::VERSION
  s.authors     = ["Stew Eucen"]
  s.email       = ["stew.eucen@gmail.com"]
  s.homepage    = 'http://lab.kochlein.com/FertileForest'
  s.summary     = 'The new model to store hierarchical data in a database.'
  s.description = 'Fertile Forest is the new model to store hierarchical data in a database. Conventional models are "adjacency list", "route enumeration", "nested set" and "closure table". Fertile Forest has some excellent features than each conventional model.'
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.rdoc"]

  s.required_ruby_version = ">= 2.1.5"

  ### s.add_dependency "rails"###, "~> 4.2.1"
  s.add_dependency "rails", ">= 4.2"

  ###s.add_development_dependency "sqlite3"

  ### TODO: dependancy for MySQL version
end
