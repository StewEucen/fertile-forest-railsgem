# Fertile Forest Model for Ruby on Rails

[![Software License](https://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat-square)](LICENSE.txt)

This RailsGem is an implementation of the Fertile Forest Model for ActiveRecord. It is a replacement for all RailsGems of nested sets pattern, maybe more awesome.

## What's Fertile Forest Model?

We know four models for storing hierarchical data in a database.

1. Adjacency List Model
2. Path Enumeration Model
3. Nested Sets Model (and Nested Intervals Model)
4. Closure Table Model

Fertile Forest Model (FF model) is the fifth model. FF model has some awesome features than traditional four models. Stew Eucen who is the Japanese database engineer discovered it.

This is the first implementation of Fertile Forest Model for RailsGem.

## More Information

You can learn more about Fertile Forest Model at:

* [Fertile Forest Model (official)](http://lab.kochlein.com/FertileForest)

## Environments

I confirmed this model operations by the environments:

* Ruby 2.1.5 p273
* Ruby on Rails 4.2.1
* MySQL 5.6.23

## Installation

Add to your Gemfile:

```ruby
gem 'fertile_forest'
```

## Usage

This RailsGem has 2 ways for using:

1. as single woods style
2. as multiple woods style

To make use of `acts_as_fertile_forest` your model needs to have 2 fields: `ff_queue` and `ff_depth`. When you use multiple woods style, needs more `ff_grove`. If the model not contain `ff_grove`, the model acts as single woods style automatically. The names of these fields are configurable.

A role of `ff_grove` is like `user_id`. When the model use some tree data for each user, this field is very useful.

Original FF model does not need `ff_grove`. Therefore, FF model requires only two fields for storing hierarchical data in a database. However, I contained `ff_grove` into this RailsGem for our convenience.

Migrate file as single wood style:
```ruby
class CreateSingleWoods < ActiveRecord::Migration
  def change
    create_table :single_woods do |t|
      t.integer :ff_depth, null: false
      t.integer :ff_queue, null: false
      t.string :title

      t.timestamps null: false
    end

    add_index :single_woods, [:ff_queue           ], :name => 'ff_queue_index'
    add_index :single_woods, [:ff_depth, :ff_queue], :name => 'ff_depth_index'
  end
end
```

Migrate file as multiple wood style:
```ruby
class CreateMultipleWoods < ActiveRecord::Migration
  def change
    create_table :multiple_woods do |t|
      t.integer :ff_grove, null: false
      t.integer :ff_depth, null: false
      t.integer :ff_queue, null: false
      t.string :title

      t.timestamps null: false
    end

    add_index :multiple_woods, [:ff_grove, :ff_queue           ], :name => 'ff_queue_index'
    add_index :multiple_woods, [:ff_grove, :ff_depth, :ff_queue], :name => 'ff_depth_index'
  end
end
```

Enable the FF model functionality by declaring `acts_as_fertile_forest` on your model.

```ruby
class YourModelNames < ActiveRecord::Base
  acts_as_nested_set
end
```

When you want to use alias name of FF fields:

```ruby
class YourModelNames < ActiveRecord::Base
  acts_as_fertile_forest {
    aliases: {
      ff_grove: :user_id,
      ff_queue: :queue,
      ff_depth: :depth,
    }
  }
end
```

## How to contribute

* If you find a bug, or want to contribute an enhancement or a fix, please send a pull request according to GitHub rules.<br>
https://github.com/StewEucen/fertile-forest-railsgem

* Please post in your SNS:
```
We got the new model for storing hierarchical data in a database.
Stew Eucen did it!
```

Copyright © 2015 Stew Eucen, released under the MIT license
