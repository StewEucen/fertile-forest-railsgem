##
#
# states methods for Table
#
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
        module States
          #
          # Are all nodes siblings?
          # @param args [Array] Nodes.
          # @return [Boolean] Returns true is those are sibling nodes.
          # @todo is full flag
          #
          def siblings?(*args)
            sibling_nodes = ff_resolve_nodes(args.flatten)

            # get id hash by nested information
            eldest_node = sibling_nodes.values.first
            full_sibling_nodes = siblings(eldest_node, [@_id]).all

            child_hash = {}
            bingo_count = sibling_nodes.length
            full_sibling_nodes.each do |the_node|
              the_id = the_node.id
              child_hash[the_id] = the_node
              # ruby has no --xxxx
              bingo_count -= 1 if sibling_nodes.has_key?(the_id)
            end

            # return value
            if bingo_count == 0
              child_hash
            else
              false
            end
          end

          #
          # Is root node?
          # @param node_obj [Entity|Integer] Node of Entity|int to check.
          # @return [Boolean] Returns true is this is root node.
          #
          def root?(node_obj)
            aim_node = ff_resolve_nodes(node_obj)
            return nil if aim_node.blank?       # nil as dubious

            aim_node.ff_depth == ROOT_DEPTH     # never ===
          end

          #
          # Has descendant?
          # @param node_obj [Entity|Integer] Node of Entity|int to check.
          # @return [Boolean] Returns true is this has descendant node.
          #
          def has_descendant?(node_obj)
            aim_node = ff_resolve_nodes(node_obj)
            return nil if aim_node.blank?       # nil as dubious

            aim_query = ff_subtree_scope(
                aim_node,
                false,          # without top
                true            # use COALESCE()
              )
              .select(@_id)

            # FIXME: When use COALESCE(), can not act query.count
            # 0 < aim_query.count
            aim_query.first.present?
          end

          #
          # Is leaf node?
          # @param node_obj [Entity|Integer] Node of Entity|int to check.
          # @return [Boolean] Returns true is this is leaf node.
          #
          def leaf?(node_obj)
            result = has_descendant?(node_obj)    # nil as dubious
            return nil if result.nil?

            !result
          end

          #
          # Is internal node?
          #   "internal" means non-leaf and non-root.
          # @param node_obj [Entity|Integer] Node of Entity|int to check.
          # @return [Boolean] Returns true is this is leaf node.
          #
          def internal?(node_obj)
            aim_node = ff_resolve_nodes(node_obj)
            return nil if aim_node.blank?       # nil as dubious

            aim_node.ff_depth != ROOT_DEPTH && has_descendant?(node_obj)
          end

          #
          # Has sibling node?
          # @param node_obj [Entity|Integer] Node of Entity|int to check.
          # @return [Boolean] Returns true is this has sibling node.
          #
          def has_sibling?(node_obj)
            aim_node = ff_resolve_nodes(node_obj)
            return nil if aim_node.blank?       # nil as dubious

            aim_depth = aim_node.ff_depth
            # root node has no sibling
            return false if aim_depth == ROOT_DEPTH

            parent_node = genitor(aim_node)
            # null as dubious, because no parent is irregular
            return nil if parent_node.blank?

            ffdd = arel_table[@_ff_depth]
            aim_query = ff_subtree_scope(
                parent_node,
                false,          # without top
                false           # use COALESCE()
                # true          # FIXME: COALESCE() true makes error
              )
              .where(ffdd.eq(aim_depth))

            1 < aim_query.count
          end

          #
          # Is only child?
          # @param node_obj [Entity|Integer] Node of Entity|int to check.
          # @return [Boolean] Returns true is this is only child node.
          #
          def only_child?(node_obj)
            has_sibling = has_sibling?(node_obj)
            return nil if has_sibling.nil?    # nil as dubious

            !has_sibling
          end

          #
          # Is reserching node descendant of base node?
          # @param base_obj [Entity|Integer] Entity|int of base node to check.
          # @param researches [Array] Research nodes.
          # @return [Array] Item of array true is it is descendant node of base node.
          #
          def descendant?(base_obj, researches = [])
            aim_node = ff_resolve_nodes(base_obj)
            return nil if aim_node.blank?   # nil as dubious

            is_plural = researches.is_a?(Array)
            return (is_plural ? [] : nil) if researches.blank?

            # need to be "id => node" for checking grove
            research_nodes = ff_resolve_nodes(
              is_plural ? researches : [researches],
              true    # refresh
            )

            boundary_queue = ff_get_boundary_queue(aim_node)
            aim_tail_queue = (boundary_queue.blank? \
              ? QUEUE_MAX_VALUE
              : boundary_queue - 1
            )

            aim_queue = aim_node.ff_queue
            aim_grove = aim_node.ff_grove

            res = {}

            research_nodes.each_pair do |the_id, the_node|
              if the_node.present? && the_node.ff_grove == aim_grove
                the_queue = the_node.ff_queue
                res[the_id] = aim_queue < the_queue && the_queue <= aim_tail_queue
              else
                res[the_id] = nil
              end
            end

            is_plural ? res : res.values.first
          end

          #
          # Is reserching node ancestor of base node?
          # @param base_obj [Entity|Integer] Entity|int of base node to check.
          # @param researches [Array] Research nodes.
          # @return [Array] Item of array true is it is ancestor node of base node.
          #
          def ancestor?(base_obj, researches = [])
            aim_node = ff_resolve_nodes(base_obj)
            return nil if aim_node.blank?   # nil as dubious

            is_plural = researches.is_a?(Array)
            return (is_plural ? [] : nil) if researches.blank?

            # need to be "id => node" for checking grove
            research_nodes = ff_resolve_nodes(
              is_plural ? researches : [researches],
              true    # refresh
            )

            exists_hash = {}
            Array(ancestors(aim_node)).each { |node| exists_hash[node.id] = true }

            res = {}
            research_nodes.each_pair do |the_id, the_node|
              res[the_id] = exists_hash[the_id]
            end

            is_plural ? res : res.values.first
          end

          #
          # Calculate height of subtree.
          #   When want to get root height as:
          #    (1) get height of any node.
          #    (2) root height = height of the node + depth of the node.
          # Height of empty tree is "-1"<br>
          # http://en.wikipedia.org/wiki/Tree_(data_structure)
          # @param base_obj [Entity|Integer] Base node|id to check.
          # @return [Integer] Height of subtree of base node.
          # @return [nil] Invalid input (base node is nil).
          #
          def height(base_obj)
            aim_node = ff_resolve_nodes(base_obj)
            return nil if aim_node.blank?   # nil as dubious

            ffdd = arel_table[@_ff_depth]

            # with top, use COALESCE()
            height_res = ff_subtree_scope(aim_node, SUBTREE_WITH_TOP_NODE, true)
              .select(ffdd.maximum.as('ff_height'))
              .first

            return nil if height_res.blank?   # nil as dubious

            height_res.ff_height - aim_node.ff_depth
          end

          #
          # Calculate size of subtree.
          # @param base_obj [Entity|Integer] Base node|id to check.
          # @return [Integer] Size of subtree of base node.
          # @return [nil] Invalid input (base node is nil).
          #
          def size(base_obj)
            aim_node = ff_resolve_nodes(base_obj)
            return nil if aim_node.blank?   # nil as dubious

            ffdd = arel_table[@_ff_depth]

            # with top, use COALESCE()
            size_res = ff_subtree_scope(aim_node, SUBTREE_WITH_TOP_NODE, true)
                .select(ffdd.count.as('ff_count'))
                .first

            return nil if size_res.blank?   # nil as dubious

            size_res.ff_count
          end

        end
      end
    end
  end
end
