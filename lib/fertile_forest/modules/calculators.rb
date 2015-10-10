#
# Calcurators methods
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
        # @private
        module Calculators

          def fill_required_columns_to_append!(node)
            # calculate depth and queue for appending.
            # If no interval, try to scoot over queue.
            if node.ff_base_id.to_i <= 0
              fill_info = ff_calc_required_columns_for_appending_as_root(node)
            else
              fill_info = ff_calc_required_columns_for_appending_as_internal(node)
            end

            # When fail to calc, can not save.
            # no need to set error message here.
            return false if fill_info.blank?

            # not need to set ff_grove, because posted node has it already.
            node.ff_queue = fill_info[:ff_queue]
            node.ff_depth = fill_info[:ff_depth]

            true
          end

          def ff_parse_kinship(node)
            ff_kinship_key = node.ff_kinship
            if /true|false/i.match(ff_kinship_key)
              ff_kinship_key === 'true'
            else
              ff_kinship_key.to_i
            end
          end

          #
          # Calculate depth and queue as root node to append.
          # @return [Hash] Calculated queue and depth.
          # @return [false] Can not calculate.
          #
          def ff_calc_required_columns_for_appending_as_root(node)
            # can be null=zero
            posted_grove = node.ff_grove.to_i

            # When append as root, need to post ff_grove.
            if has_grove? && posted_grove <= 0
              # TODO: set error message 'append_empty_column'
              return false
            end

            # depth is fixed value
            fill_info = {ff_depth: ROOT_DEPTH}

            ####################################################################
            #
            # calculate queue
            #

            # get max queue in grove
            last_queue = ff_get_last_queue(posted_grove)  # can be nil

            if last_queue.nil?
              append_queue = 0
            elsif QUEUE_MAX_VALUE <= last_queue
              # Try to scoot over pre-nodes.
              evenize_res = ff_evenize(posted_grove, nil, nil, 1) # 1: append node count

              # When fail to evenize, filled all id.
              if evenize_res.blank?
                # TODO: set error append.canNotScootsOver'
                return false
              end

              append_queue = evenize_res[SPROUT_VACANT_QUEUE_KEY]
            elsif QUEUE_MAX_VALUE - last_queue < QUEUE_DEFAULT_INTERVAL
              append_queue = QUEUE_MAX_VALUE
            else
              append_queue = last_queue + QUEUE_DEFAULT_INTERVAL
            end

            # return value
            fill_info.merge({ff_queue: append_queue})
          end

          #
          # Calculate depth and queue as internal node to append.
          #  (1) has space before base-node, calc median queue.
          #  (2) When no space befre base node, try to evenize.
          #  (3) can not evenize, can not append.
          # @return [Hash] Calculated queue and depth.
          # @return [false] Can not calculate.
          #
          def ff_calc_required_columns_for_appending_as_internal(node)
            base_id = node.ff_base_id.to_i
            grove_id = node.ff_grove.to_i

            # get base node by ff_base_id
            # use ff_grove for find, because grove means USER_ID
            base_node = ff_required_columns_scope()
              .ff_usual_conditions_scope(grove_id)
              .where(id: base_id)
              .first

            # When has ff_base_id and the node is nothing, fail to append.
            if base_node.blank?
              # TODO: set errors append.baseNodeIsNull
              return false
            end

            kinship = ff_parse_kinship(node)
            is_sibling = ff_is_bool(kinship)

            # depth is fixed value
            fill_info = {ff_depth: base_node.ff_depth.to_i + (is_sibling ? 0 : 1)}

            # pick up node for wedged node to scoot over. (can be null)
            wedged_node = ff_get_wedged_node(base_node, kinship)

            # When wedged node is nothing, it means last queue.
            # In the case, calc appending queue is "lastQueue + INTERVAL"

            if wedged_node.blank?
              last_queue = ff_get_last_queue(grove_id, 0)
              if last_queue < QUEUE_MAX_VALUE
                if QUEUE_DEFAULT_INTERVAL <= QUEUE_MAX_VALUE - last_queue
                  calc_queue = last_queue + QUEUE_DEFAULT_INTERVAL
                else
                  calc_queue = QUEUE_MAX_VALUE
                end

                return fill_info.merge({ff_queue: calc_queue})
              end
            else
              #
              # When got wedged node, calc median queue.
              #  (1) get previous node of the wedge node.
              #  (2) calc median queue.
              #
              append_queue = ff_calc_median_queue(wedged_node)

              return fill_info.merge({ff_queue: append_queue}) \
                  if append_queue.present?
            end

            # When no space before wedged node, try to scoot over.
            append_queue = ff_evenize_for_appending(base_node, wedged_node)

            return fill_info.merge({ff_queue: append_queue}) \
                if append_queue.present?

            # TODO: set error message append.canNotScootsOver
            false
          end

          def ff_calc_median_queue(wedged_node)
            tail_node = ff_get_previous_node(wedged_node)

            # tail_node never be null, because parent-node exists.
            return nil if tail_node.blank?

            tail_queue = tail_node.ff_queue
            wedged_queue = wedged_node.ff_queue

            return nil if wedged_queue - tail_queue <= 1

            # not need to use (int)
            (tail_queue + wedged_queue) / 2
          end

          def ff_evenize_for_appending(base_node, wedged_node)
            append_node_count = 1

            grove_id     = base_node.ff_grove
            base_queue   = base_node.blank?   ? nil : base_node .ff_queue
            wedged_queue = wedged_node.blank? ? nil : wedged_node.ff_queue

            # try to evenize all pre-nodes from this base node.
            evenize_res = ff_evenize(grove_id, base_queue, wedged_queue, append_node_count)
            return evenize_res[SPROUT_VACANT_QUEUE_KEY] if evenize_res.present?

            # try to evenize all pre-nodes from this root node.
            # {
            #     $rootNode = $this->root($baseNode);
            #     $evenizeRes = $this->_evenize($grove, $rootNode, $wedgedQueue, $appendNodeCount);
            #     if (!empty($evenizeRes)) {
            #         return $evenizeRes[self::SPROUT_VACANT_QUEUE_KEY];
            #     }
            # }

            # try to evenize all pre-nodes.
            evenize_res = ff_evenize(grove_id, nil, wedged_queue, append_node_count)
            return evenize_res[SPROUT_VACANT_QUEUE_KEY] if evenize_res.present?

            # try to evenize all post-nodes.
            evenize_res = ff_evenize(grove_id, wedged_queue, nil, append_node_count, true)
            return evenize_res[SPROUT_VACANT_QUEUE_KEY] if evenize_res.present?

            # can not evenize.
            false
          end

          protected :ff_parse_kinship,
                    :ff_calc_required_columns_for_appending_as_root,
                    :ff_calc_required_columns_for_appending_as_internal,
                    :ff_calc_median_queue,
                    :ff_evenize_for_appending

        end
      end
    end
  end
end
