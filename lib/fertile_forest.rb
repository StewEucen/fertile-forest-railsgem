require 'active_record'

require 'fertile_forest/engine'
require 'fertile_forest/saplings'
require 'fertile_forest/version'

ActiveRecord::Base.send :extend, StewEucen::Acts::FertileForest::Table
