#
# Fertile Forest for Ruby
# The new model for storing hierarchical data in a database.
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
      #
      # Instance methods to include into derived class by ActiveRecord.
      #
      # @author StewEucen
      # @example Include into ActiveRecord class.
      #   ActiveRecord::Base.send :include, StewEucen::Acts::FertileForest::Entity
      # @since  Release 1.0.0
      #
      module Entity
        #
        # Before save listener (must be an instance methoed).
        # Transparently manages setting the required fields for FertileForestBehavior
        # if the parent field is included in the parameters to be saved.
        #
        # @return boolean true:Continue to save./false:Abort to save.
        #
        def ff_before_save
          # when not new record, to update.
          # no need to set ff_columns (id, grove, queue, depth)
          return true unless new_record?

          if self.class.has_grove?
            posted_grove = self.ff_grove
            if posted_grove.blank?
              # TODO: set_error
              return false
            end
          end

          # return value
          self.class.fill_required_columns_to_append!(self)
        end

        def ff_before_create
        end

        def ff_after_save
        end

        def ff_before_destroy
        end

        protected :ff_before_save,
                  :ff_before_create,
                  :ff_after_save,
                  :ff_before_destroy

        ########################################################################

        def ff_reset_values
          {
              parent: {0 => nil},
            children: {},
          }
        end

        def ff_get_options
          @fertile_forest ||= ff_reset_values
        end

        def nest_unset_parent
          ff_get_options[:parent] = {0 => nil}
        end

        def nest_unset_children(id = nil)
          if id.blank?
            ff_get_options[:children] = {}
          else
            ff_get_options[:children][id] = nil
          end
        end

        ##
        #
        # accessors
        #
        #
        ########################################################################

        def nest_parent_node
          ff_get_options[:parent].values.first
        end

        def nest_child_nodes
          ff_get_options[:children]
        end

        def nest_parent_id
          ff_get_options[:parent].keys.first
        end

        def nest_child_ids
          ff_get_options[:children].keys
        end

        alias nest_parent   nest_parent_node
        alias nest_genitor  nest_parent_node
        alias nest_children nest_child_nodes

        ########################################################################

        def nest_set_parent_id(aim_id)
          ff_get_options[:parent] = {aim_id => nil}  # always overwrite
        end

        def nest_set_child_id(aim_id)
          ff_get_options[:children][aim_id] = nil
        end

        ########################################################################

        def nest_set_parent_node(aim_id, node)
          ff_get_options[:parent] = {aim_id => node} \
              if aim_id.present? && node.present?
        end

        def nest_set_child_node(aim_id, node)
          ff_get_options[:children][aim_id] = node \
              if aim_id.present? && node.present?
        end

        ########################################################################

        def nest_leaf?
          ff_get_options[:children].blank?
        end

        def nest_parent?
          !nest_leaf?
        end

        ########################################################################

        def trunk(range = ANCESTOR_ALL, columns = nil)
          self.class.trunk(self, range, columns)
        end

        def ancestors(columns = nil)
          self.class.ancestors(self, columns)
        end

        def genitor(columns = nil)
          self.class.genitor(self, columns)
        end

        def root(columns = nil)
          self.class.root(self, columns)
        end

        def grandparent(columns = nil)
          self.class.grandparent(self, columns)
        end

        def subtree(range = DESCENDANTS_ALL, with_top = true, columns = nil)
          self.class.subtree(self, range, with_top, columns)
        end

        def descendants(columns = nil)
          self.class.descendants(self, columns)
        end

        def children(columns = nil)
          self.class.children(self, columns)
        end

        def nth_child(nth = 0, columns = nil)
          self.class.nth_child(self, nth, columns)
        end

        def grandchildren(columns = nil)
          self.class.grandchildren(self, columns)
        end

        def siblings(columns = nil)
          self.class.siblings(self, columns)
        end

        def nth_sibling(nth = 0, columns = nil)
          self.class.nth_sibling(self, nth, columns)
        end

        def elder_sibling(columns = nil)
          self.class.elder_sibling(self, columns)
        end

        def younger_sibling(columns = nil)
          self.class.younger_sibling(self, columns)
        end

        def offset_sibling(offset, columns = nil)
          self.class.offset_sibling(self, offset, columns)
        end

        def leaves(columns = nil)
          self.class.leaves(self, columns)
        end

        def internals(columns = nil)
          self.class.internals(self, columns)
        end

        def height
          self.class.height(self)
        end

        def size
          self.class.size(self)
        end

        protected :ff_reset_values,
                  :ff_get_options
      end
    end

  end
end
