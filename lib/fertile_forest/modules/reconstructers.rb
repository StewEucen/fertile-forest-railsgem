##
#
# restructure methods for Table
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
        module Reconstructers
          #
          # Graft subtree nodes.
          #
          # @param aim_obj [Entity|Integer] Top node of subtree to graft.
          # @param base_obj [Entity|Integer] Base node to calc wedged queue.
          # @param kinship [Boolean|Integer] Graft position from base_obj.
          #   Integer: As child.
          #   Boolean: As sibling.
          # @return [Boolean] true: Success.
          # @return [Boolean] false: Failure.
          #
          def graft(aim_obj, base_obj, kinship = -1)
            transaction do
              nodes = ff_resolve_nodes([aim_obj, base_obj], true).values   # refresh
              aim_node = nodes[0]
              base_node = nodes[1]

              raise ActiveRecord::Rollback if aim_node.blank? || base_node.blank?

              # pick up node for wedged node to scoot over. (can be null)
              wedged_node = ff_get_wedged_node(base_node, kinship)

              is_sibling = ff_is_bool(kinship)
              depth_offset = base_node.ff_depth - aim_node.ff_depth + (is_sibling ? 0 : 1)

              return true if ff_fit_to_graft(aim_node, wedged_node, depth_offset)

              # return value
              ff_scoots_over(aim_node, wedged_node, depth_offset)
            end   # transaction end
          end

          protected

            def ff_get_wedged_node(base_node, kinship)
              is_sibling = ff_is_bool(kinship)

              if is_sibling
                ff_get_wedged_node_as_sibling(base_node, kinship)
              else
                ff_get_wedged_node_as_child(base_node, kinship)
              end
            end

            def ff_get_wedged_node_as_child(base_node, nth)
              # pickup wedged node by order of children
              if 0 <= nth
                nth_child = ff_nth_child(base_node, nth)
                return nth_child if nth_child.present?
              end

              ff_get_boundary_node(base_node)   # can be null
            end

            def ff_get_wedged_node_as_sibling(base_node, after_sibling_node)
              if after_sibling_node
                ff_get_boundary_node(base_node)
              else
                base_node
              end
            end

            def ff_fit_to_graft(graft_node, wedged_node, depth_offset)
              shift_queue = graft_node.ff_queue
              shift_grove = graft_node.ff_grove

              if has_grove? && shift_grove.blank?
                # TODO: set error
                return false
              end

              # exists subquery, can not work @compare_depth (avert to use coalesce())
              graft_query = ff_subtree_scope(graft_node, SUBTREE_WITH_TOP_NODE, false)

              # count grafting subtree span of queue
              shift_boundary_queue = ff_get_boundary_queue(graft_node)
              max_queue = ff_get_last_queue(shift_grove, 0) \
                  if shift_boundary_queue.blank? || wedged_node.blank?

              if shift_boundary_queue.blank?
                shift_span = max_queue - shift_queue + 1
              else
                shift_span = shift_boundary_queue - shift_queue
              end

              if wedged_node.blank?
                wedged_space = QUEUE_MAX_VALUE - max_queue
              else
                prev_queue = ff_get_previous_queue(wedged_node)
                wedged_space = wedged_node.ff_queue - prev_queue - 1
              end

              # If fit to graft as it is, execute to graft.
              if shift_span <= wedged_space
                if wedged_node.blank?
                  queue_offset = max_queue - shift_queue + 1
                else
                  queue_offset = prev_queue - shift_queue + 1
                end

                return false if queue_offset == 0 && depth_offset == 0

                graft_query = graft_query

                update_columns = []
                update_columns << "ff_queue = ff_queue + #{queue_offset}" \
                    if queue_offset != 0

                update_columns << "ff_depth = ff_depth + #{depth_offset}" \
                    if depth_offset != 0

                return 0 < graft_query.update_all(update_columns.join(', '))
              end

              # try to fit to shift with evenizing.
              node_count = graft_query.count

              if node_count <= wedged_space
                return false if node_count < 1

                return false if wedged_node.blank? && depth_offset == 0

                # SET fields
                queue_interval = [QUEUE_DEFAULT_INTERVAL, wedged_space / node_count].min.to_i
                start_queue = (wedged_node.blank? ? max_queue : prev_queue) + 1 - queue_interval

                update_columns[:ff_queue] = "@forest_queue := @forest_queue + #{queue_interval}"
                update_columns[:ff_depth] = "ff_depth + #{depth_offset}" \
                    if depth_offset != 0

                # WHERE conditions
                update_conditions = ff_create_usual_conditions_hash(shift_grove)
                  update_conditions['ff_queue >='] = shift_queue          if shift_queue.present?
                  update_conditions['ff_queue <' ] = shift_boundary_queue if shift_boundary_queue.present?

                # use raw query, because can not use ORDER BY in standard updateAll().
                update_rows = ff_update_all_in_order(
                  update_columns,
                  update_conditions,
                  ff_usual_order_array(),
                  "SET @forest_queue = #{start_queue}"
                )

                return 0 < update_rows.to_i
              end

              # can not fit to shift
              false
            end

            def ff_scoots_over(shift_node, wedged_node, depth_offset)
              # find boundary node of shift node (can be null)
              aim_boundary_node = ff_get_boundary_node(shift_node)

              return false unless ff_can_graft_by_node(shift_node, aim_boundary_node, wedged_node)

              aim_grove = shift_node.ff_grove
              aim_queue = shift_node.ff_queue

              max_queue = ff_get_last_queue(aim_grove, 0) \
                  if aim_boundary_node.blank? || wedged_node.blank?

              if aim_boundary_node.blank?
                aim_tail_queue = max_queue
              else
                aim_tail_queue = aim_boundary_node.ff_queue - 1
              end

              if wedged_node.blank?
                wedged_tail_queue = max_queue
              else
                wedged_tail_queue = wedged_node.ff_queue - 1
              end

              # moving direction progress/retrogress
              # when same queue, as retrogress. Therefore use "<=".
              is_retrogression = wedged_tail_queue <= aim_queue

              # moving distance
              move_offset = is_retrogression \
                ? wedged_tail_queue - aim_queue + 1
                : wedged_tail_queue - aim_tail_queue

              involved_offset = (aim_tail_queue - aim_queue + 1) * (is_retrogression ? 1 : -1)

              queue_offset_case = is_retrogression \
                ? ff_create_case_expression(
                    nil,
                    [["ff_queue < #{aim_queue}", involved_offset]],
                    move_offset
                  )
                : ff_create_case_expression(
                    nil,
                    [["ff_queue <= #{aim_tail_queue}", move_offset]],
                    involved_offset
                  )

              ffqq = arel_table[@_ff_queue]
              ffdd = arel_table[@_ff_depth]
              ffgg = arel_table[@_ff_grove]

              # WHERE conditions
              head_queue = is_retrogression ? wedged_tail_queue + 1 : aim_queue
              tail_queue = is_retrogression ? aim_tail_queue        : wedged_tail_queue
              scoots_over_query = ff_usual_conditions_scope(aim_grove)
                .where(ffqq.gteq(head_queue))
                .where(ffqq.lteq(tail_queue))

              # UPDATE SET columns
              # To set depth must be firstly, because it include condition of queue.
              # If to set queue firstly, depth condition is changed before set.
              update_columns = []
              if depth_offset != 0
                depth_offset_case = ff_create_case_expression(
                  nil,
                  [[
                    [ffqq.gteq(aim_queue).to_sql, 'AND', ffqq.lteq(aim_tail_queue).to_sql].join(' '),
                    depth_offset
                  ]],
                  #[["#{aim_queue} <= ff_queue AND ff_queue <= #{aim_tail_queue}", depth_offset]],
                  0
                )
                update_columns << "ff_depth = ff_depth + (#{depth_offset_case})"
                #update_columns << "ff_depth = ff_depth + (#{depth_offset_case})"
              end
              update_columns << "ff_queue = ff_queue + (#{queue_offset_case})"

              # return value
              0 < scoots_over_query.update_all(update_columns.join(', '))
            end

            def ff_can_graft_by_node(aim_node, aim_boundary_node, wedged_node)
              # When no wedged node, it means that last queue.
              # In the case, can shift always
              # TODO: should think with boundary node is null
              return true if wedged_node.blank?

              # If grove is different, can not shift.
              if has_grove? && aim_node.ff_grove != wedged_node.ff_grove
                # TODO: set error restructure.defferentGroves'
                return false
              end

              #
              # If wedged queue between the shifting subtree, can not shift.
              # head < wedged < boundary
              #
              # can be "head == wedged". It is OK for shifting.
              # because it means "depth-shifting".
              #
              # 2015/04/30
              # float type aborted to use, because float has arithmetic error.
              #
              wedged_queue = wedged_node.ff_queue

              # can be "head == wedged". It is OK for shifting.
              # because it means "depth-shifting".
              return true if wedged_queue <= aim_node.ff_queue

              # In this case, must use boundary queue.
              if aim_boundary_node.blank?
                # TODO: set error restructure.graftIntoOwn
                return false
              end

              # It is safe.
              return true if aim_boundary_node.ff_queue < wedged_queue

              # TODO: set error restructure.graftIntoOwn'
              return false
            end

          public

          #
          # Reorder sibling nodes.
          #
          # @param args [mixed] Sibling nodes to permute.
          # @return [Boolean] true: Success.
          # @return [Boolean] false: Failure.
          #
          def permute(*args)
            node_args = args.flatten

            transaction do
              sibling_nodes = ff_resolve_nodes(node_args, true)  # refresh

              # if node is only one, nothing to do.
              raise ActiveRecord::Rollback if sibling_nodes.length < 2

              # Aer they siblings?
              current_orderd_child_nodes = siblings?(sibling_nodes.values)

              raise ActiveRecord::Rollback if current_orderd_child_nodes.blank?

              # if they are siblings, yield to permute.

              # create array new orderd nodes.
              new_orderd_sibling_nodes = []
              new_orderd_ids = sibling_nodes.keys

              current_orderd_child_nodes.each_pair do |the_id, the_node|
                if sibling_nodes.has_key?(the_id)
                  picked_id = new_orderd_ids.shift
                  new_orderd_sibling_nodes << current_orderd_child_nodes[picked_id]
                else
                  new_orderd_sibling_nodes << node
                end
              end

              # get sorted nodes of all siblings by queue.
              # TODO: need or not need?
              current_queue_orderd_nodes = ff_queue_sorted_nodes(current_orderd_child_nodes.values)

              # calc each siblingNode information.

              # get tail node
              tail_node = current_queue_orderd_nodes.last
              aim_grove = tail_node.ff_grove

              # get total boundary queue (can be null)
              siblings_boundary_queue = ff_get_boundary_queue(tail_node)
              total_tail_queue = siblings_boundary_queue.blank? \
                  ? ff_get_max_queue(aim_grove, 0)
                  : siblings_boundary_queue - 1

              # set by current order.
              node_attr_infos = {}
              current_queue_orderd_nodes.each do |node|
                node_attr_infos[node.id] = {}
              end

              last_node_index = current_queue_orderd_nodes.length - 1

              node_id_hash = {}
              current_queue_orderd_nodes.each.with_index do |the_node, i|
                is_last = i == last_node_index
                the_id = the_node.id
                node_attr_infos[the_id][:is_last] = is_last

                the_tail_queue = (is_last \
                    ? total_tail_queue
                    : (current_queue_orderd_nodes[i + 1].ff_queue - 1)
                )
                node_attr_infos[the_id][:tail_queue] = the_tail_queue

                # calc queue-width each sibling
                node_attr_infos[the_id][:queue_width] = the_tail_queue - the_node.ff_queue + 1

                # must use &$xxxx, because do not clone node instance.
                node_id_hash[the_id] = the_node
              end

              # get shifted range of queues
              range_queue_head = current_queue_orderd_nodes.first.ff_queue

              # calc moving queue span for each node.
              has_changed = false
              reduce_queue = range_queue_head   # default value of new queue.
              new_orderd_sibling_nodes.each do |the_node|
                update_id = the_node.id
                off = reduce_queue - node_id_hash[update_id].ff_queue

                node_attr_infos[update_id][:ff_offset] = off
                has_changed = true if off != 0

                reduce_queue += node_attr_infos[update_id][:queue_width]
              end

              # no move, no update.
              return false unless has_changed

              # create case for update by original order of queue.
              when_hash = ['CASE']
              current_queue_orderd_nodes.each do |node|
                orign_id = node.id
                aim_info = node_attr_infos[orign_id]

                off = aim_info[:ff_offset]
                if aim_info[:is_last]
                  when_hash << "ELSE #{off}"
                else
                  when_hash << "WHEN ff_queue <= #{aim_info[:tail_queue]} THEN #{off}"
                end
              end
              when_hash <<= 'END'

              case_string = when_hash.join(' ')

              # execute to update all
              # lteq(total_tail_queue) is for max_queue
              ffqq = arel_table[@_ff_queue]
              res = ff_usual_conditions_scope(aim_grove)
                  .ff_usual_order_scope()
                  .where(ffqq.gteq(range_queue_head))
                  .where(ffqq.lteq(total_tail_queue))
                  .update_all("ff_queue = ff_queue + (#{case_string})")

              res
            end     # transaction end
          end

          #
          # Permute in siblings as "Move To".
          # @param node_obj [Entity|Integer] Moved node by Entity|id.
          # @param nth [Integer] Move rank in sibling. (-1:As last sibling)
          # @return [Boolean] true: Success.
          # @return [Boolean] false: Failure.
          #
          def move_to(node_obj, nth = -1)
            ff_move_node(node_obj, nth, false)   # false: move to
          end

          #
          # Permute in siblings as "Move By".
          # @param node_obj [Entity|Integer] Moved node by Entity|id.
          # @param step [Integer] Moving offset.
          # @return [Boolean] true: Success.
          # @return [Boolean] false: Failure.
          #
          def move_by(node_obj, step)
            ff_move_node(node_obj, step, true)   # true: move by
          end

          protected

            def ff_move_node(node_obj, move_number, as_move_by = false)
              aim_node = ff_resolve_nodes(node_obj)
              return false if aim_node.blank?

              siblings_query = siblings(aim_node, [@_id])
              return false if siblings_query.blank?
              sibling_nodes = siblings_query.all

              aim_id = aim_node.id

              move_number = move_number.to_i

              # get orderd rank from move_number
              if as_move_by
                return false if move_number == 0

                nth = nil
                sibling_nodes.each.with_index do |node, i|
                  if node.id == aim_id
                    nth = i
                    break
                  end
                end

                return false if nth.nil?

                nth = [0, nth + move_number].max
                nth = -1 if sibling_nodes.length <= nth
              else
                nth = move_number
              end

              nth = sibling_nodes.length - 1 if nth < 0

              return false if sibling_nodes.length <= nth

              return false if sibling_nodes[nth].id == aim_id

              new_orderd_nodes = []
              sibling_nodes.each do |node|
                new_orderd_nodes << node if node.id != aim_id
              end

              new_orderd_nodes.insert(nth, aim_node)

              permute(new_orderd_nodes)
            end

          public

          #
          # Remove the node and shift depth of descendant nodes.
          #   soft delete
          #    (1) soft delete
          #    (2) grove delete
          #    (3) normal delete
          # @param node_obj [Entity|Integer] Node to remove.
          # @return [Boolean] true: Success.
          # @return [Boolean] false: Failure.
          #
          def remove(node_obj)
            transaction do
              remove_node = ff_resolve_nodes(node_obj, true)       # refresh
              raise ActiveRecord::Rollback if remove_node.blank?   # nil as dubious

              aim_queue = remove_node.ff_queue
              aim_depth = remove_node.ff_depth
              aim_grove = remove_node.ff_grove

              # get range of descendants for shifting these depth
              if aim_depth == ROOT_DEPTH
                offset_depth = 1
              else
                parent_node = genitor(remove_node)
                raise ActiveRecord::Rollback if parent_node.blank?

                offset_depth = aim_depth - parent_node.ff_depth
              end

              # for soft delete
              # can not use subquery for same table in UPDATE
              # Mysql2::Error: You can't specify target table 'categories' for update in FROM clause:
              remove_query = ff_subtree_scope(remove_node, true, false)

              ffdd = arel_table[@_ff_depth]

              update_columns = []
              depth_value = ff_create_case_expression(
                @_ff_queue,
                [[aim_queue, 0]],               # when then
                "ff_depth - #{offset_depth}"    # else value
              )
              update_columns << "ff_depth = (#{depth_value})"

              if has_soft_delete? || enable_grove_delete?
                if has_soft_delete?
                  delete_value = ff_create_case_expression(
                    @_ff_queue,
                    [[aim_queue, ff_options[:delete_value]]],     # when then
                    @_ff_soft_delete    # else value
                  )
                  update_columns << "#{@_ff_soft_delete} = (#{delete_value})"
                else
                  delete_value = ff_create_case_expression(
                    @_ff_queue,
                    [[aim_queue, -1]],    # when then
                    1                     # else value
                  )
                  update_columns << "#{@_ff_grove} = #{@_ff_grove} * (#{delete_value})"
                end

                res = remove_query.update_all(update_columns.join(', '))

              # hard delete
              else
                update_res = remove_query.update_all(update_columns.join(', '))
                res = delete_all(@_id => remove_node.id)
              end

              res
            end   # tansaction end
          end

          #
          # Prune subtree nodes.
          # @param base_obj [Entity|Integer] Top node to prune.
          # @param with_top [Boolean] Include base node in return query.
          # @return [Boolean] true: Success.
          # @return [Boolean] false: Failure.
          #
          def prune(base_obj, with_top = false)
            transaction do
              aim_node = ff_resolve_nodes(base_obj, true)       # refresh
              raise ActiveRecord::Rollback if aim_node.blank?   # nil as dubious

              aim_queue = aim_node.ff_queue
              aim_depth = aim_node.ff_depth
              aim_grove = aim_node.ff_grove

              # boundry queue (can be nil)
              aim_boundary_queue = ff_get_boundary_queue(aim_node)

              # for soft delete
              # can not use subquery for same table in UPDATE
              # Mysql2::Error: You can't specify target table 'categories' for update in FROM clause:
              prune_query = ff_subtree_scope(aim_node, with_top, false)

              # soft delete
              if has_soft_delete?
                delete_key = @_ff_soft_delete
                res = prune_query.update_all("#{delete_key} = #{ff_options[:delete_value]}")
              elsif enable_grove_delete?
                grove_key = @_ff_grove
                res = prune_query.update_all("#{grove_key} = #{grove_key} * -1")
              else
                res = prune_query.delete_all
              end

              res
            end   # tansaction end
          end

          #
          # Extinguish (remove top node and the descendant nodes).
          # @param base_obj [Entity|Integer] Top node to extinguish.
          # @return [Boolean] true: Success.
          # @return [Boolean] false: Failure.
          #
          def extinguish(base_obj)
            prune(base_obj, SUBTREE_WITH_TOP_NODE)
          end

          #
          # Pollard (remove the descendant nodes).
          # @param base_obj [Entity|Integer] Top node to pollard.
          # @return [Boolean] true: Success.
          # @return [Boolean] false: Failure.
          #
          def pollard(base_obj)
            prune(base_obj, SUBTREE_WITHOUT_TOP_NODE)
          end

          ######################################################################

          #
          # Normalize ff_queue fields in ordered grove.
          # @param node_obj [Entity|Integer] Start node.
          # @param boundary_node_obj [Entity|Integer] Boundary node.
          # @return [Boolean] true: Success.
          # @return [Boolean] false: Failure.
          #
          def normalize_queue(node_obj = nil, boundary_node_obj = nil)
            transaction do
              # nodes can be nil
              aim_node = ff_resolve_nodes(node_obj)
              aim_boundary_node = ff_resolve_nodes(boundary_node_obj)

              aim_top_queue      = aim_node         .blank? ? nil : aim_node         .ff_queue
              aim_boundary_queue = aim_boundary_node.blank? ? nil : aim_boundary_node.ff_queue

              res = ff_evenize(aim_node.ff_grove, aim_top_queue, aim_boundary_queue, 0)  # 0: no appmend node

              # return value
              if res.present?
                res[EVENIZE_AFFECTED_ROWS_KEY]
              else
                false
              end
            end
          end

          protected

            def ff_evenize(
              grove_id,
              aim_queue,
              aim_boundary_queue,
              add_count,
              rear_justified = false
            )
              return nil if has_grove? && grove_id.to_i <= 0

              # can evenize?
              # 1.0 <= (boundaryQueue - headQueue) / (updatedNodeCount + appendNodeCount)
              can_evenize = ff_can_evenize(grove_id, aim_queue, aim_boundary_queue, add_count)
              return nil if can_evenize.blank?

              queue_interval = can_evenize[:queue_interval]
              node_count     = can_evenize[:node_count]

              # execute to slide

              # calc defaut value of new queues
              # add_count can be 0
              head_queue = aim_queue || 0
              if rear_justified
                start_queue = head_queue + queue_interval * (add_count - 1)
              else
                start_queue = head_queue - queue_interval
              end

              #
              # excute update query
              #

              # exists subquery, can not work @compare_depth (avert to use coalesce())
              # Use both query "SET @ffqq = xxx" and "COALESCE(@ffqq, xxx)",
              # because connection is cut between SET and UPDATE
              update_conditions = ff_create_usual_conditions_hash(grove_id)
                update_conditions['ff_queue >='] = aim_queue          if aim_queue.present?
                update_conditions['ff_queue <' ] = aim_boundary_queue if aim_boundary_queue.present?

              update_rows = ff_update_all_in_order(
                {ff_queue: "@forest_queue := @forest_queue + #{queue_interval}"},
                update_conditions,
                ff_usual_order_array(),
                "SET @forest_queue = #{start_queue}"
              )

              return nil if update_rows.to_i <= 0

              # return value
              {
                SPROUT_VACANT_QUEUE_KEY   => head_queue + (rear_justified ? 0 : queue_interval * node_count),
                EVENIZE_AFFECTED_ROWS_KEY => update_rows,
              }
            end

            def ff_can_evenize(grove_id, aim_queue, aim_boundary_queue, add_count)
              # get count of node for UPDATE
              ffqq = arel_table[@_ff_queue]
              aim_query = ff_usual_conditions_scope(grove_id)

              aim_query.where!(ffqq.gteq(aim_queue))        if aim_queue.present?
              aim_query.where!(ffqq.lt(aim_boundary_queue)) if aim_boundary_queue.present?

              evenizing_count = aim_query.count

              head_queue = aim_queue || 0

              # can nomalize?
              divid_number = evenizing_count + add_count
              return nil if divid_number < 1

              # get boundary queue for calc
              if aim_boundary_queue.present?
                aim_queue_span = aim_boundary_queue - head_queue
              else
                max_queue = ff_get_last_queue(grove_id, 0)     # 0 for nil
                request_queue_span = QUEUE_DEFAULT_INTERVAL * (add_count + 1)

                if QUEUE_MAX_VALUE - max_queue < request_queue_span
                  aim_queue_span = QUEUE_MAX_VALUE - head_queue + 1
                else
                  aim_queue_span = max_queue - head_queue + request_queue_span
                end
              end

              queue_interval = aim_queue_span / divid_number

              return nil if queue_interval < 1

              # return value
              {
                queue_interval: queue_interval,
                node_count:     evenizing_count,
              }
            end

          public

          #
          # Normalize ff_depth fields in ordered grove.
          #
          # @param  grove_id [Integer|nil] Grove ID to find.
          # @return [Boolean] true: Success.
          # @return [Boolean] false: Failure.
          #
          def normalize_depth(grove_id = nil)
            transaction do
              return false if has_grove? && grove_id.blank?

              feature_key = 'ff_is_fault'

              columns = [
                "@compare_depth + 1 < (@compare_depth := ff_depth) AS #{feature_key}",
              ]

              ffqq = arel_table[@_ff_queue]
              ffdd = arel_table[@_ff_depth]

              # exists subquery, can not work @compare_depth (avert to use coalesce())
              aim_query = ff_required_columns_scope(columns)
                  .ff_usual_order_scope()
                  .ff_usual_conditions_scope(grove_id)
                  .having(feature_key)
                  .limit(1000)

                  # TODO: subtreeLimitSize

              ff_raw_query("SET @compare_depth = #{ROOT_DEPTH}")

              depth_offset_values = []
              aim_query.all.each do |node|
                prev_node = ff_get_previous_node(node)

                next if prev_node.blank?

                offset = node.ff_depth - prev_node.ff_depth - 1;
                top_queue = prev_node.ff_queue
                top_depth = prev_node.ff_depth
                top_grove = prev_node.ff_grove if has_grove?

                new_node = prev_node.clone

                depth_offets = [];
                (1 .. offset).each do |o|
                  new_node.ff_depth = top_depth + o
                  depth_offets << ff_get_boundary_queue(new_node)
                end

                grove_condition = has_grove? ? "#{@_ff_grove} = #{top_grove} AND" : '';

                depth_offets.each do |boundary_queue|
                  boundary_condition = boundary_queue.blank? \
                      ? ''
                      : "AND ff_queue < #{boundary_queue}"

                  depth_offset_values << "(CASE WHEN #{grove_condition} #{top_queue} < ff_queue #{boundary_condition} THEN 1 ELSE 0 END)"
                end
              end

              return false if depth_offset_values.blank?

              update_query = ff_usual_conditions_scope(grove_id)
              update_rows = update_query.update_all(
                  "#{@_ff_depth} = #{@_ff_depth} - " + depth_offset_values.join('-')
              )

              # return value
              0 < update_rows.to_i
            end
          end

          def ff_usual_order_array(is_descent = false)
            direction = is_descent ? 'DESC' : 'ASC'
            res = {}
            res[:ff_soft_delete] = direction if has_soft_delete?
            res[:ff_grove      ] = direction if has_grove?
            res[:ff_depth      ] = direction if is_descent
            res[:ff_queue      ] = direction

            res
          end

          protected :ff_usual_order_array
        end
      end
    end
  end
end
