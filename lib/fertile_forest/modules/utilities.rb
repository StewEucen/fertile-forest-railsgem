#
# Utilities methods.
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
        module Utilities

          def ff_is_bool(aim_obj)
            aim_obj.kind_of?(TrueClass) || aim_obj.kind_of?(FalseClass)
          end

          def ff_raw_query(query_string)
            connection.execute(query_string, :skip_logging)
          end

          def ff_quoted_column(column, with_table = true)
            keyString = column.to_s
            resolved_column = attribute_aliases[keyString] || keyString

            quoted_column = connection.quote_column_name(resolved_column)

            if with_table
              "#{quoted_table_name}.#{quoted_column}"
            else
              quoted_column
            end
          end

          #
          # Update all by raw query with ORDER BY clause and pre-query of user variable.
          # Update() do not use order() in Ruby on Rails 4.x.
          # This method is the solution to workaround it.
          #
          # 2015/06/01
          # This method is for raw query to update,
          # because Rails standard method "update_all()" can not use @ffqq.
          # Reason why connection is broken from "SET @ffqq = started_value".
          #
          # @param predicates [Hash] A hash of predicates for SET clause.
          # @param conditions [Hash] Conditions to be used, accepts anything Query::where() can take.
          # @param order      [Hash] Order clause.
          # @param prequeries [Hash] Execute Prequeries before UPDATE for setting the specified local variables.
          # @return [Integer|Boolean] Count Returns the affected rows | false.
          #
          def ff_update_all_in_order(predicates, conditions, order, prequeries = nil)
            update_fields = []
            predicates.each_pair do |key, value|   # NOTICE string value
              quoted = ff_quoted_column(key)
              update_fields << "#{quoted} = #{value}"
            end

            update_conditions = []
            conditions.each_pair do |key, value|
              if key.is_a?(Integer)
                update_conditions << value
              else
                quoted = ff_quoted_column(key)
                if value.is_a?(Array)
                  joined = value.join(',')
                  update_conditions << "#{quoted} IN (#{joined})"
                else
                  info = key.to_s.split(' ')
                  if 1 < info.length
                    picked_column = ff_quoted_column(info.shift.to_sym)
                    join_list = [picked_column] + info + [value]
                    update_conditions << join_list.join(' ')
                  else
                    update_conditions << "#{quoted} = #{value}"
                  end
                end
              end
            end

            update_order = []
            order.each_pair do |key, value|
              direction = key.is_a?(Integer) ? 'ASC' : value
              quoted = ff_quoted_column(key)
              update_order << "#{quoted} #{direction}"
            end

            # pre-query to SET @xxx := value
            # can execuete two query() at once, however can not get affectedRows.
            prequeries = [prequeries] unless prequeries.instance_of?(Array)
            prequeries.each { |query| ff_raw_query(query) }

            # use raw query, because can not use ORDER BY in standard updateAll().
            update_query_string = [
              'UPDATE',
                quoted_table_name(),   # OK `categories`
              'SET',
                update_fields.join(', '),
              'WHERE',
                update_conditions.map { |cond| "(#{cond})" }.join(' AND '),
              'ORDER BY',
                update_order.join(', '),
            ].join(' ')

            # return value
            connection.update(update_query_string)
          end

          def ff_create_case_expression(key, whens_thens, else_str)
            joined_list = ["CASE", key]
            whens_thens.each do |item|
              joined_list += ["WHEN", item[0], "THEN", item[1]]
            end
            joined_list << ["ELSE", else_str, "END"]

            joined_list.join(' ')
          end

          #
          # Resolve node from Entity|int params.
          #
          # @param nodes [ActiveRecord::Base|Integer|Array] To identify the nodes.
          # @param refresh [Boolean] true:Refind each Entity by id.
          # @return [ActiveRecord::Base|Hash] When nodes is array, return value is hash.
          #
          def ff_resolve_nodes(nodes, refresh = false)
            return nodes if nodes.blank?
            is_plural = nodes.is_a?(Array)
            nodes = [nodes] unless is_plural

            res_entities = {}
            refind_ids   = []
            nodes.each do |item|
              is_node = item.is_a?(ActiveRecord::Base)
              if is_node
                the_id = item.id
              else
                the_id = item.to_i
              end

              if !is_node || refresh
                refind_ids << the_id
                res_entities[the_id] = nil
              else
                res_entities[the_id] = item
              end
            end

            ##
            # get node orderd by id
            #
            if refind_ids.present?
              aim_query = ff_usual_conditions_scope(nil)
                .where(id: refind_ids)
                .ff_required_columns_scope()

              aim_query.all.each do |node|
                res_entities[node.id] = node
              end
            end

            # return value
            is_plural ? res_entities : res_entities.values.first
          end

          protected :ff_is_bool,
                    :ff_raw_query,
                    :ff_quoted_column,
                    :ff_update_all_in_order,
                    :ff_create_case_expression,
                    :ff_resolve_nodes

        end
      end
    end
  end
end
