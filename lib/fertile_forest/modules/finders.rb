require 'active_record'
#
# Finder methods
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
        module Finders
          #
          # Find trunk (= ancestor) nodes from base node in ordered range.
          #
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param range [Integer] Ordered range of trunk nodes.
          #   -1:To designate as root node.
          # @param columns [Array] Columns for SELECT clause.
          # @return [ActiveRecord::Relation] Basic query for finding trunk nodes.
          # @return [nil] No trunk nodes.
          #
          def trunk(base_obj, range = ANCESTOR_ALL, columns = nil)
            base_node = ff_resolve_nodes(base_obj)
            return nil if base_node.blank?

            aim_queue = base_node.ff_queue
            aim_depth = base_node.ff_depth
            aim_grove = base_node.ff_grove  # When no grove, nil

            return nil if aim_depth == ROOT_DEPTH

            ffqq = arel_table[@_ff_queue]
            ffdd = arel_table[@_ff_depth]
            ffgg = arel_table[@_ff_grove]

            # create subquery to find queues of ancestor
            aim_subquery = ff_usual_projection(aim_grove)
                .where(ffqq.lt(aim_queue))

            if range < 0
              aim_subquery = aim_subquery.where(ffdd.eq(ROOT_DEPTH))
            else
              aim_subquery = aim_subquery.where(ffdd.lt(aim_depth))
              aim_subquery = aim_subquery.where(ffdd.gteq(aim_depth - range)) \
                  if 0 < range
            end

            aim_group = [ffdd]
            aim_group.unshift(ffgg) if has_grove?

            aim_subquery = aim_subquery.project(ffqq.maximum.as('ancestor_queue'))
              .group(aim_group)

            # find nodes by ancestor queues
            # must use IN(), because trunk() is for general purpose to find ancestors
            # When one row, can use "=". When plural, can not use "=".
            # Error: SQLSTATE[21000]: Cardinality violation: 1242 Subquery returns more than 1 row
            ff_required_columns_scope()
                .ff_usual_conditions_scope(aim_grove)
                .ff_usual_order_scope()
                .where(ffqq.in(aim_subquery))
                .select(ff_all_optional_columns(columns))
          end

          #
          # Find all ancestor nodes from base node (without base node).
          #
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param columns [Array] Columns for SELECT clause.
          # @return [ActiveRecord::Relation] Basic query for finding ancestor nodes.
          # @return [nil] No ancestor nodes.
          #
          def ancestors(base_obj, columns = nil)
            trunk(base_obj, ANCESTOR_ALL, columns)
          end

          #
          # Find genitor (= parent) node from base node.
          #
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param columns [Array] Columns for SELECT clause.
          # @return [Entity] Genitor node.
          # @return [nil] No genitor node.
          #
          def genitor(base_obj, columns = nil)
            trunk_query = trunk(base_obj, ANCESTOR_ONLY_PARENT, columns)

            return nil if trunk_query.blank?

            trunk_query.first
          end

          #
          # Find root node from base node.
          #
          # @param base_obj [Entity|int] Base node|id to find.
          # @param columns [Array] Columns for SELECT clause.
          # @return [Entity] Root node. When base node is root, return base node.
          # @return [Enil] No root node.
          #
          def root(base_obj, columns = nil)
            base_node = ff_resolve_nodes(base_obj)
            return nil if base_node.blank?

            return base_node if base_node.ff_depth == ROOT_DEPTH

            trunk_query = trunk(base_node, ANCESTOR_ONLY_ROOT, columns)
            return nil if trunk_query.blank?

            trunk_query.first
          end

          #
          # Find grandparent node from base node.
          #
          # @param base_obj [Entity|int] Base node|id to find.
          # @param columns [Array] Columns for SELECT clause.
          # @return [Entity] Grandparent node.
          # @return [nil] No grandparent node.
          #
          def grandparent(base_obj, columns = nil)
            base_node = ff_resolve_nodes(base_obj)
            return nil if base_node.blank?

            grand_number = 2

            grandparent_depth = base_node.ff_depth - grand_number
            return nil if grandparent_depth < ROOT_DEPTH

            trunk_query = trunk(base_node, grand_number, columns)
            return nil if trunk_query.blank?

            trunk_query.first
          end

          #
          # Find cenancestor nodes of given nodes from base node.
          #
          # @param objects [Array] Array of base nodes|ids to find.
          # @param columns [Array] Columns for SELECT clause.
          # @return [Entity] Grandparent node.
          # @return [nil] No grandparent node.
          # @since 1.2.0
          def cenancestors(objects, columns = nil)
            base_nodes = ff_resolve_nodes(objects)
            return nil if base_nodes.blank?

            entities = base_nodes.values

            # if bases include null, can not find.
            return nil if entities.include? nil

            # check same grove.
            if has_grove?
              groves = entities.map {|n| n.ff_grove }
              return nil if groves.min != groves.max
            end

            eldist_node = entities.first;
            aim_grove = eldist_node.ff_grove  # When no grove, nil

            ffqq = arel_table[@_ff_queue]
            ffdd = arel_table[@_ff_depth]
            ffgg = arel_table[@_ff_grove]

            queues = entities.map {|n| n.ff_queue }
            head_queue = queues.min
            tail_queue = queues.max

            # create subquery to find top-depth in range of head-tail.
            top_depth_subquery = ff_usual_projection(aim_grove)
                .project(ffdd.minimum.as('top_depth'))
                .where(ffqq.gteq(head_queue))
                .where(ffqq.lteq(tail_queue))

            # create subquery to find queues of ancestors.
            aim_group = [ffdd]
            aim_group.unshift(ffgg) if has_grove?

            cenancestor_nodes_subquery = ff_usual_projection(aim_grove)
                .project(ffqq.maximum.as('ancestor_queue'))
                .where(ffqq.lt(head_queue))
                .where(ffdd.lt(top_depth_subquery))
                .group(aim_group)

            # find nodes by ancestor queues
            # must use IN(), because trunk() is for general purpose to find ancestors
            # When one row, can use "=". When plural, can not use "=".
            # Error: SQLSTATE[21000]: Cardinality violation: 1242 Subquery returns more than 1 row
            ff_required_columns_scope()
                .ff_usual_conditions_scope(aim_grove)
                .ff_usual_order_scope()
                .where(ffqq.in(cenancestor_nodes_subquery))
                .select(ff_all_optional_columns(columns))
          end

          ######################################################################

          #
          # Find subtree nodes from base node with ordered range.
          #
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param range [Integer] Ordered range of trunk nodes. -1:To designate as root node.
          # @param withTop [boolean] Include base node in return query.
          # @param fields [Array] Fields for SELECT clause.
          # @return [ActiveRecord::Relation] Basic query for finding subtree nodes.
          # @return [nil] No subtree nodes.
          #
          def subtree(base_obj, range = DESCENDANTS_ALL, with_top = true, columns = nil)
            base_node = ff_resolve_nodes(base_obj)
            return [] if base_node.blank?

            aim_query = ff_required_columns_scope(columns)
              .ff_subtree_scope(
                base_node,
                with_top,
                true   # use COALESCE() must be false for children().count
              )

            ffdd = arel_table[@_ff_depth]
            limited = ff_limited_subtree_depth(
              base_node.ff_depth,
              range,
              aim_query
            )

            aim_query.where!(ffdd.lteq(limited)) if 0 < limited

            aim_query
              .select(ff_all_optional_columns(columns))
              .ff_usual_order_scope()
          end

          #
          # Count each depth for pagination in finding subtree nodes.
          # @param base_depth [Integer] Depth of base node.
          # @param range [Integer] Ordered depth offset.
          # @param subtree_query [Projection] WHERE clause for finding subtree to count.
          # @return [Integer] Max depth in query to find subtree nodes.
          #
          def ff_limited_subtree_depth(base_depth, range, subtree_query)
            orderd_depth = range == 0 ? 0 : (base_depth + range)

            ffdd = arel_table[@_ff_depth]

            count_query = subtree_query
              .select(ffdd.count('*').as('depth_count'))
              .group(ffdd)

            limited = self.ff_options[:subtree_limit_size]

            total_size = 0
            limited_depth = 0

            count_query.each do |depth_entity|
              aim_depth = depth_entity.ff_depth
              aim_count = depth_entity.depth_count

              braek if limited < total_size += aim_count

              limited_depth = aim_depth
            end

            limited_depth = [limited_depth, base_depth + 1].max

            if orderd_depth == 0
              limited_depth
            else
              [limited_depth, orderd_depth].min
            end
          end

          #
          # Find descendant nodes from base node.
          #
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param columns [Array]       Columns for SELECT clause.
          # @return [ActiveRecord::Relation] Basic query for finding descendant nodes.
          # @return [nil] No descendant nodes.
          #
          def descendants(base_obj, columns = nil)
            subtree(base_obj, DESCENDANTS_ALL, false, columns)
          end

          #
          # Find child nodes from base node.
          #
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param columns [Array] Columns for SELECT clause.
          # @return [ActiveRecord::Relation] Basic query for finding child nodes.
          # @return [nil] No child nodes.
          #
          def children(base_obj, columns = nil)
            subtree(base_obj, DESCENDANTS_ONLY_CHILD, false, columns)
          end

          #
          # Find nth-child node from base node.
          #
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param nth [Integer] Order in child nodes.
          # @param columns [Array] Columns for SELECT clause.
          # @return [Entity] Nth-child node.
          # @return [nil] No nth-child node.
          #
          def nth_child(base_obj, nth = 0, columns = nil)
            children_query = children(base_obj, columns)

            nth = nth.to_i
            if nth < 0
              sibling_count = children_query.all.length
              nth = sibling_count - 1
              return nil if nth < 0
            end

            children_query.offset(nth).first
          end

          #
          # Find grandchild nodes from base node.
          #
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param columns [Array] Columns for SELECT clause.
          # @return [ActiveRecord::Relation] Basic query for finding grandchild nodes.
          # @return [nil] No grandchild nodes.
          #
          def grandchildren(base_obj, columns = nil)
            base_node = ff_resolve_nodes(base_obj)
            return [] if base_node.blank?

            grand_number = 2

            # return value
            subtree(
                base_node,
                grand_number,
                SUBTREE_WITHOUT_TOP_NODE,
                columns
              )
              .where(@_ff_depth => base_node.ff_depth + grand_number)
          end

          #
          # Find any kind of kinship from base node.
          #
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param branch_level [Integer] Branch distance of finding nodes from base nodes.
          # @param depth_offset [Integer] Offset of kinship level of finding nodes from base nodes.
          # @param columns [Array] Columns for SELECT clause.
          # @return [ActiveRecord::Relation] Basic query for finding kinship nodes.
          # @return [nil] No kinship nodes.
          # @since 1.1.0
          #
          def kinships(
            base_obj,
            branch_level = KINSHIPS_BRANCH_LEVEL_ONE,
            depth_offset = KINSHIPS_SAME_DEPTH,
            columns = nil
          )
            base_node = ff_resolve_nodes(base_obj)
            return nil if base_node.blank?

            aim_queue = base_node.ff_queue
            aim_depth = base_node.ff_depth
            aim_grove = base_node.ff_grove  # When no grove, nil

            top_depth = aim_depth - branch_level

            # Impossible to find.
            return nil if top_depth < ROOT_DEPTH

            return nil if branch_level + depth_offset < 0

            ffqq = arel_table[@_ff_queue]
            ffdd = arel_table[@_ff_depth]
            ffgg = arel_table[@_ff_grove]

            # create subquery
            before_nodes_subquery = ff_usual_projection(aim_grove)
                .project(ffqq.maximum.to_sql + " + 1 AS head_queue")
                .where(ffqq.lt(aim_queue))
                .where(ffdd.lteq(top_depth))

            after_nodes_subquery = ff_usual_projection(aim_grove)
                .project(ffqq.minimum.to_sql + " - 1 AS tail_queue")
                .where(ffqq.gt(aim_queue))
                .where(ffdd.lteq(top_depth))

            func_maker = Arel::Nodes::NamedFunction

            before_coalesce_condition = func_maker.new(
                'COALESCE',
                [before_nodes_subquery, 0]
            )

            after_coalesce_condition = func_maker.new(
                'COALESCE',
                [after_nodes_subquery, QUEUE_MAX_VALUE]
            )

            # find nodes by ancestor queues
            ff_required_columns_scope()
                .ff_usual_conditions_scope(aim_grove)
                .ff_usual_order_scope()
                .where(ffdd.eq(aim_depth + depth_offset))
                .where(ffqq.gteq(before_coalesce_condition))
                .where(ffqq.lteq(after_coalesce_condition))
                .select(ff_all_optional_columns(columns))
          end

          #
          # Find sibling nodes from base node.
          # Note: Results includes base node.
          #
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param columns [Array] Columns for SELECT clause.
          # @return [ActiveRecord::Relation] Basic query for finding sibling nodes.
          # @return [nil] No sibling nodes.
          # @version 1.1.0 Replace to use kinships()
          #
          def siblings(base_obj, columns = nil)
            kinships(base_obj, KINSHIPS_BRANCH_LEVEL_ONE, KINSHIPS_SAME_DEPTH, columns)
          end

          #
          # Find cousin nodes from base node.
          # Note: Results includes siblngs nodes.
          #
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param columns [Array] Columns for SELECT clause.
          # @return [ActiveRecord::Relation] Basic query for finding cousin nodes.
          # @return [nil] No cousin nodes.
          # @since 1.1.0
          def cousins(base_obj, columns = nil)
            kinships(base_obj, KINSHIPS_BRANCH_LEVEL_TWO, KINSHIPS_SAME_DEPTH, columns)
          end

          #
          # Find aunt|uncle nodes from base node.
          # Note: Results includes siblngs nodes.
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param columns [Array] Columns for SELECT clause.
          # @return [ActiveRecord::Relation] Basic query for finding aunt|uncle nodes.
          # @return [nil] No aunt|uncle nodes.
          # @since 1.1.0
          #
          def piblings(base_obj, columns = nil)
            kinships(base_obj, KINSHIPS_BRANCH_LEVEL_TWO, KINSHIPS_PARENT_DEPTH, columns)
          end

          #
          # Find nibling nodes from base node.
          # Note: Results includes siblngs nodes.
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param columns [Array] Columns for SELECT clause.
          # @return [ActiveRecord::Relation] Basic query for finding nibling nodes.
          # @return [nil] No nibling nodes.
          # @since 1.1.0
          #
          def niblings(base_obj, columns = nil)
            kinships(base_obj, KINSHIPS_BRANCH_LEVEL_ONE, KINSHIPS_CHILD_DEPTH, columns)
          end

          #
          # Find nth-sibling node from base node.
          #
          # @param base_obj [Entity|Integer] Base node|id to find.
          # @param nth [Integer] Order in child nodes.
          # @param [Array] columns  Columns for SELECT clause.
          # @return [Entity] Nth-sibling node.
          # @return [nil] No nth-sibling node.
          #
          def nth_sibling(base_obj, nth = 0, columns = nil)
            base_node = ff_resolve_nodes(base_obj)
            return nil if base_node.blank?

            parent_node = genitor(base_node)
            return nil if parent_node.blank?

            nth = nth.to_i
            nth_child(parent_node, nth, columns)
          end

          #
          # Find elder sibling node from base node.
          #
          # @param  base_obj [Entity|Integer] Base node|id to find.
          # @param  columns [Array] Columns for SELECT clause.
          # @return [Entity] Elder sibling node of base node.
          # @return [nil] No elder sibling node.
          #
          def elder_sibling(base_obj, columns = nil)
            offset_sibling(base_obj, -1, columns)
          end

          #
          # Find younger sibling node from base node.
          #
          # @param  base_obj [Entity|Integer] Base node|id to find.
          # @param  columns [Array] Columns for SELECT clause.
          # @return [Entity] Younger sibling node of base node.
          # @return [nil] No younger sibling node.
          #
          def younger_sibling(base_obj, columns = nil)
            offset_sibling(base_obj, 1, columns)
          end

          #
          # Find offsetted sibling node from base node.
          #
          # @param  base_obj [Entity|Integer] Base node|id to find.
          # @param  offset [Integer]  Order in child nodes.
          # @param  columns [Array] Columns for SELECT clause.
          # @return [Entity] Offsetted sibling node from base node.
          # @return [nil] No offsetted sibling node.
          #
          def offset_sibling(base_obj, offset, columns = nil)
            base_node = ff_resolve_nodes(base_obj)
            return nil if base_node.blank?

            parent_node = genitor(base_node)
            return nil if parent_node.blank?

            sibling_nodes = children(parent_node, [@_id]).all
            return nil if sibling_nodes.blank?

            base_id = base_node.id

            nth = nil
            Array(sibling_nodes).each.with_index do |node, i|
              if node.id == base_id
                nth = i
                break
              end
            end

            return nil if nth.nil?

            offset = offset.to_i

            # OFFSET -1 make an error
            # Error: SQLSTATE[42000]: Syntax error or access violation: 1064 You have an error in your SQL syntax;
            # check the manual that corresponds to your MySQL server version for the right syntax to use near '-1' at line 1
            return nil if nth + offset < 0

            nth_child(parent_node, nth + offset, columns)
          end

          #
          # Find leaf nodes from base node.
          #
          # @param  base_obj [Entity|Integer] Base node|id to find.
          # @param  columns [Array] Columns for SELECT clause.
          # @return [Array] Basic query for finding leaf nodes.
          # @return [nil] No leaf nodes.
          # @todo   Pagination, Create limit as desc.
          #
          def leaves(base_obj, columns = nil)
            ff_features(base_obj, false, columns)
          end

          #
          # Find internal nodes from base node.
          #
          # @param  base_obj [Entity|Integer] Base node|id to find.
          # @param  columns [Array] Columns for SELECT clause.
          # @return [Array] Basic query for finding internal nodes.
          # @return [nil] No internal nodes.
          #
          def internals(base_obj, columns = nil)
            ff_features(base_obj, true, columns)
          end

          #
          # Find feature nodes in subtree from base node.
          # feature nodes
          #  (1) leaves
          #  (2) internals
          # @param  base_obj [Entity|Integer] Base node|id to find.
          # @param  is_feature_internal [Boolean] true:Internal nodes|false:Leaf nodes.
          # @param  columns [Array] Columns for SELECT clause.
          # @return [Array] Found nodes.
          # @return [nil] No nodes.
          #
          def ff_features(base_obj, is_feature_internal = false, columns = nil)
            base_node = ff_resolve_nodes(base_obj)
            return nil if base_node.blank?

            feature_key = 'ff_is_it'

            ffqq = arel_table[@_ff_queue]
            ffdd = arel_table[@_ff_depth]

            # exists subquery, can not work @compare_depth (avert to use coalesce())
            aim_query = ff_required_columns_scope(columns)
                .ff_usual_order_scope(true)
                .ff_subtree_scope(base_node)
                .select(ff_all_optional_columns(columns))

            if is_feature_internal
              aim_query = aim_query.select("@compare_depth > (@compare_depth := ff_depth) AS #{feature_key}")
            else
              aim_query = aim_query.select("@compare_depth <= (@compare_depth := ff_depth) AS #{feature_key}")
            end

            aim_query.having!(feature_key)

            ff_raw_query("SET @compare_depth = #{ROOT_DEPTH}")

            aim_query.all.reverse
            # must use .all, because this query has @xxxx.
          end

          #
          # Find all nodes in grove.
          # @param  grove_id [Integer|nil] Grove ID to find.
          # @param  columns [Array] Columns for SELECT clause.
          # @return [ActiveRecord::Relation] Query for finding nodes.
          # @todo   Pagination.
          #
          def grove_nodes(grove_id = nil, columns = nil)
            ff_usual_conditions_scope(grove_id)
              .ff_usual_order_scope()
          end

          #
          # Find all root nodes in grove.
          #
          # @param  grove_id [Integer|nil] Grove ID to find.
          # @param  columns [Array] Columns for SELECT clause.
          # @return [ActiveRecord::Relation] Query for finding nodes.
          # @todo   Pagination.
          #
          def roots(grove_id = nil, columns = nil)
            grove_id = grove_id.to_i
            ffdd = arel_table[@_ff_depth]
            ff_usual_conditions_scope(grove_id)
                .ff_usual_order_scope()
                .where(ffdd.eq(ROOT_DEPTH))
          end

          #
          # Find grove informations that has enable (not soft deleted and not grove deleted).
          #
          # @return [ActiveRecord::Relation] Query for finding grove ids.
          # @todo Test.
          #
          def groves
            return nil unless has_grove?

            ffid = arel_table[@_ff_id]
            ffgg = arel_table[@_ff_grove]

            ff_usual_conditions_scope()
                .select([ffgg, ffid.count('*').as('ff_count')])
                .group([ffgg])
          end

          #
          # Create nested nodes from subtree nodes.
          #
          # @param haystack_nodes [ActiveRecord::Relation|Array] Iteratorable nodes data.
          # @return [Hash|Array] When has grove is Hash, otherwise Array.
          #
          def nested_nodes(haystack_nodes)
            return {} if haystack_nodes.blank?

            #
            # pick up nodes by iterator
            #  (1) array
            #  (2) query
            #  (3) ResultSet
            # return by hash [id => node]
            #
            sorted_nodes = ff_queue_sorted_nodes(haystack_nodes)
            return {} if sorted_nodes.blank?

            # ネストがroot(=1)からじゃない場合の対応
            # queueで並べた先頭のdepthを暫定root depthとする
            the_root_depth = sorted_nodes[0].ff_depth

            sorted_nodes.each do |node|
              node.nest_unset_parent
              node.nest_unset_children
            end

            # 遡って見えているnodesを格納する配列
            retro_nodes = {}
            if has_grove?
              sorted_nodes.each do |node|
                retro_nodes[node.ff_grove] = []
              end
            else
              retro_nodes[:singular] = []
            end

            # 戻り値の生成用の、IDをキーとしたhashによるnest情報
            res_nested_nodes = {}

            grove_key = :singular
            sorted_nodes.each do |node|
              the_id = node.id
              depth = node.ff_depth

              grove_key = node.ff_grove if has_grove?

              res_nested_nodes[the_id] = node;  # 今回のnodesを登録

              depth_index = depth - the_root_depth   # ネストがroot(=1)からじゃない場合の対応
              parent_depth_index = depth_index - 1

              # このnodeに親があれば、親子関係を登録
              if 0 <= parent_depth_index && retro_nodes[grove_key][parent_depth_index].present?
                parent_id = retro_nodes[grove_key][parent_depth_index]

                res_nested_nodes[parent_id].nest_set_child_id(the_id)
                res_nested_nodes[the_id].nest_set_parent_id(parent_id)
              end

              # 今回の深度のところまで親リストを消した上で自分を登録する
              retro_nodes[grove_key] = retro_nodes[grove_key].slice(0, depth_index)
              retro_nodes[grove_key][depth_index] = the_id
            end

            return res_nested_nodes unless has_grove?

            # set grove hash
            grove_res = {}

            retro_nodes.keys.each do |grove|
              grove_res[grove] = {}
            end

            res_nested_nodes.each_pair do |id, node|
              grove_res[node.ff_grove][id] = node
            end

            grove_res
          end

          #
          # Create nested IDs
          #
          # @param haystack_nodes [ActiveRecord::Relation|Array] Iteratorable nodes data.
          # @return [Array] Nested IDs data.
          #
          def nested_ids(haystack_nodes)
            res = {}
            if haystack_nodes.present?
              if has_grove?
                haystack_nodes.each_pair do |grove_id, grove_nodes|
                  res[grove_id] = {}
                  grove_nodes.each_pair do |the_id, the_node|
                    res[grove_id].merge!(ff_nest_children(the_id, grove_nodes))
                  end
                end
              else
                haystack_nodes.each_pair do |the_id, the_node|
                  res.merge!(ff_nest_children(the_id, haystack_nodes))
                end
              end
            end

            # return value
            res
          end

          # inner method for recursion
          # @scope private
          def ff_nest_children(the_id, nodes)
            return {} unless nodes.has_key?(the_id)

            children_infos = {}
            nodes[the_id].nest_child_ids.each do |child_id|
              children_infos.merge!(ff_nest_children(child_id, nodes))
            end

            nodes.delete(the_id)

            # return value
            {the_id => children_infos}
          end

          private :ff_nest_children

          def ff_get_last_node(grove_id)
            return nil if has_grove? && grove_id.to_i <= 0

            ff_usual_conditions_scope(grove_id)
                .ff_usual_order_scope(true)
                .ff_required_columns_scope()
                .first
          end

          def ff_get_last_queue(grove_id = nil, nil_value = nil)
            last_node = ff_get_last_node(grove_id)

            return nil_value if last_node.blank?

            last_node.ff_queue
          end

          def ff_get_boundary_node(base_node)
            # create subquery conditions
            boundary_queue_subquery = ff_create_boundary_queue_subquery(base_node)
            # create query to get boundary node.
            ff_required_columns_scope()
                .ff_usual_conditions_scope(base_node.ff_grove)
                .ff_usual_order_scope()
                .where(arel_table[:ff_queue].in(boundary_queue_subquery))
                .first
          end

          def ff_get_previous_node(base_node)
            return nil if base_node.blank?

            ffqq = arel_table[@_ff_queue]

            ff_usual_conditions_scope(base_node.ff_grove)
                .where(ffqq.lt(base_node.ff_queue))
                .ff_usual_order_scope(true)
                .ff_required_columns_scope()
                .first
          end

          def ff_create_boundary_queue_subquery(base_node)
            ffqq = arel_table[@_ff_queue]
            ffdd = arel_table[@_ff_depth]

            # same depth can be boundary node, therefore use LTE(<=)
            ff_usual_projection(base_node.ff_grove)
                .project(ffqq.minimum.as('boundary_queue'))
                .where(ffdd.lteq(base_node.ff_depth))
                .where(ffqq.gt  (base_node.ff_queue))
          end

          ### _createTailQueueSubquery

          def ff_get_boundary_queue(base_node)
            boundary_node = ff_get_boundary_node(base_node)
            return nil if boundary_node.blank?
            boundary_node.ff_queue
          end

          def ff_get_previous_queue(base_node)
            previous_node = ff_get_previous_node(base_node)

            return 0 if previous_node.blank?

            previous_node.ff_queue
          end

          ### _createSubtreeConditions
          ### _createCoalesceExpression

          def ff_queue_sorted_nodes(haystack_nodes)
            return [] if haystack_nodes.blank?

            res_nodes = []
            haystack_nodes.each { |node| res_nodes << node if node.present? }

            ff_sort_with_queue!(res_nodes)

            res_nodes
          end

          def ff_sort_with_queue!(haystack_nodes)
            return if haystack_nodes.blank?

            haystack_nodes.sort! do |a, b|
              a.ff_queue <=> b.ff_queue
            end
          end

          protected :ff_limited_subtree_depth,
                    :ff_features,

                    :ff_get_last_node,
                    :ff_get_last_queue,
                    :ff_get_boundary_node,
                    :ff_get_previous_node,
                    :ff_create_boundary_queue_subquery,
                    :ff_get_boundary_queue,
                    :ff_get_previous_queue,
                    :ff_queue_sorted_nodes,

                    :ff_sort_with_queue!

          alias superiors  ancestors
          alias forebears  ancestors
          alias inferiors  descendants
          alias afterbears descendants
          alias externals leaves
          alias terminals leaves
          alias nephews niblings
          alias nieces  niblings
          alias auncles piblings
          alias aunts   piblings
          alias uncles  piblings
        end
      end
    end
  end
end
