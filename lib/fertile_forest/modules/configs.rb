#
# Configs methods
# Fertile Forest for Ruby: The new model for storing hierarchical data in a database.
#
# @author StewEucen
# @copyright Copyright (c) 2015 Stew Eucen (http://lab.kochlein.com)
# @license   http://www.opensource.org/licenses/mit-license.php  MIT License
#
# @link       http://lab.kochlein.com/FertileForest
# @since      File available since Release 1.0.0
# @version    1.0.0
#
module StewEucen
  # Name space of Stew Eucen's Acts
  module Acts
    # Name space of Fertile Forest
    module FertileForest
      # Name space of class methods for Fertile Forest
      module Table
        # This module is for extending into derived class by ActiveRecord.<br>
        # The caption contains "Instance Methods",
        # but it means "Class Methods" of each derived class.
        module Configs

          #
          # Exists grove field in table?
          #
          # @author StewEucen
          # @return [Boolean] true: has grove column.
          # @return [Boolean] false: no grove column.
          # @since  Release 1.0.0
          #
          def has_grove?
            ff_has_column? :ff_grove
          end

          #
          # Exists soft-delete field in table?
          #
          # @author StewEucen
          # @return [Boolean] true: has soft-delete column.
          # @return [Boolean] false: no soft-delete column.
          # @since  Release 1.0.0
          #
          def has_soft_delete?
            ff_has_column? :ff_soft_delete
          end

          #
          # Is enable to use soft-delete by grove field?
          #
          # @author StewEucen
          # @return [Boolean] true: enable.
          # @return [Boolean] false: disable.
          # @since  Release 1.0.0
          #
          def enable_grove_delete?
            has_grove? \
                && !has_soft_delete? \
                && ff_options[:enable_grove_delete]
            # Need back slashes for this writing.
          end

          #
          # Exists field in table?
          #
          # @author StewEucen
          # @param  column [Symbol] Column symbol to check.
          # @return [Boolean] true: has specified column.
          # @return [Boolean] false: no specified column.
          # @since  Release 1.0.0
          #
          def ff_has_column?(column)
            key = column.to_s
            attribute_aliases[key] || column_names.include?(key)
          end

          #
          # Recommended queue interval for appending node.
          # Can overwrite [queue interval] at setup()/initialize().
          #
          # @author StewEucen
          # @return [Integer] Default queue interval.
          # @since  Release 1.0.0
          #
          def ff_get_query_interval
            QUEUE_DEFAULT_INTERVAL
          end

          protected :ff_has_column?,
                    :ff_get_query_interval
        end
      end
    end
  end
end
