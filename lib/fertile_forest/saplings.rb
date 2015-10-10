require 'fertile_forest/modules/configs'
require 'fertile_forest/modules/utilities'
require 'fertile_forest/modules/calculators'
require 'fertile_forest/modules/finders'
require 'fertile_forest/modules/reconstructers'
require 'fertile_forest/modules/states'
require 'fertile_forest/modules/entities'

#
# Fertile Forest for Ruby on Rails
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
      # consts used in Table and Entity
      ROOT_DEPTH = 0

      APPEND_BASE_ID_FIELD = :ff_base_id
      APPEND_NODE_RELATION_AS_LAST_CHILD    = -1
      APPEND_NODE_RELATION_AS_ELDER_SIBLING = false

      ANCESTOR_ONLY_PARENT = 1
      ANCESTOR_ONLY_ROOT   = -1
      ANCESTOR_ALL         = 0

      DESCENDANTS_ALL        = 0
      DESCENDANTS_ONLY_CHILD = 1

      PRUNE_DESCENDANTS_ONLY = false
      PRUNE_WITH_TOP_NODE    = true

      SUBTREE_WITHOUT_TOP_NODE = false
      SUBTREE_WITH_TOP_NODE    = true

      ORDER_BY_QUEUE_INDEX = false
      ORDER_BY_DEPTH_INDEX = true

      # recommended queue interval for sprouting node
      # QUEUE_DEFAULT_INTERVAL  = 3
      # QUEUE_MAX_VALUE         = 15
      QUEUE_DEFAULT_INTERVAL  = 0x8000
      QUEUE_MAX_VALUE         = 0x7fffffff   # 2147483647

      # result to scoot over
      SPROUT_VACANT_QUEUE_KEY   = :vacant_queue   # new queue to sprout
      EVENIZE_AFFECTED_ROWS_KEY = :affected_rows  # number of scooted over nodes

      @@errors = [
        append_empty_column:       'When has grove field, must set this fields.',
        append_can_not_scoot_over: 'No space to append at queue, and can not scoots over.',
        append_base_node_is_null:  'Not found base node to append.',
        restructure_empty_column:     'When has grove field, must set this fields.',
        restructure_defferent_groves: 'Defferent groves.',
        restructure_graft_into_own:   'Graft into own subtree.',
        restructure_are_not_siblings: 'Exists not sibling.',
      ]

      #
      # Table Methods to extend into ActiveRecord class.
      #
      # @author StewEucen
      # @example Extend into ActiveRecord class.
      #   ActiveRecord::Base.send :extend, StewEucen::Acts::FertileForest::Table
      # @since  Release 1.0.0
      #
      module Table
        #
        # Initializer for eech model.
        #
        # @author StewEucen
        # @example You write this method in a model of Rails as follows.
        #   class Category < ActiveRecord::Base
        #     acts_as_fertile_forest
        #   end
        #
        #   # When use alias name of columns as:
        #     acts_as_fertile_forest({
        #       aliases: {
        #         ff_queue:        :queue,
        #         ff_depth:        :depth,
        #         ff_grove:        :user_id,
        #         ff_soft_deleted: :deleted,
        #       }
        #     })
        # @param  options [Hash] Fertile Forest's options.
        # @since  Release 1.0.0
        #
        def acts_as_fertile_forest(options = {})
          # To use these modules in case fertile forest only.
          extend Configs
          extend Utilities
          extend Calculators
          extend Finders
          extend Reconstructers
          extend States

          # To change instance of ActiveRecord to Fertile Forest entity.
          include Entity

          ff_parse_options! options
          ff_resolve_alias_columns!

          # can set attr_accessor here
          attr_accessor :ff_kinship
          attr_accessor APPEND_BASE_ID_FIELD
          attr_accessor :ff_grove unless has_grove?

          ff_define_scopes!
          ff_define_alias_methods!
          ff_define_callbacks!
        end

        private

          def ff_resolve_alias_columns!
            # aliases of ff_xxxxx 2015/05/27
            if ff_options[:aliases].present?
              ff_options[:aliases].each_pair do |ff_alias, ff_origin|
                alias_attribute ff_alias, ff_origin
              end
            end

            ff_required_columns = [
              'id',
              'ff_grove',
              'ff_depth',
              'ff_queue',
              'ff_soft_delete',
            ]

            ff_required_columns.each do |key|
              instance_variable_set('@_' + key, attribute_aliases[key] || key)
            end
          end

          def ff_define_alias_methods!
            # Alias of ActiveRecord::Base::save.
            # @see ActiveRecord::Base::save.
            alias_method :sprout, :save
          end

          def ff_define_callbacks!
            before_create :ff_before_create   # must be an instance method
            before_save   :ff_before_save

            after_save     :ff_after_save
            before_destroy :ff_before_destroy
          end

          def ff_default_options
            {
              virtual_columns: {
                ff_base_id: 'ff_base_id',
              },

              enable_value: 0,
              delete_value: 1,

              enable_grove_delete: true,
              subtree_limit_size:  1000,
            }.freeze
          end

          def ff_parse_options!(options)
            options = ff_default_options.merge(options)

            class_attribute :ff_options
            self.ff_options = options
          end

          def ff_define_scopes!
            scope :ff_usual_conditions_scope, ->(grove_id = nil) do
              grove_id ||= 0

              conditions = all

              conditions.where!(ff_soft_delete: ff_options[:enable_value]) \
                  if has_soft_delete?

              if has_grove?
                if 0 < grove_id
                  conditions.where!(ff_grove: grove_id)
                else
                  conditions.where!(arel_table[@_ff_grove].gteq(0)) \
                      if enable_grove_delete?
                end
              end

              conditions
            end

            scope :ff_usual_order_scope,
              ->(is_descendant = false, is_depth_index = ORDER_BY_QUEUE_INDEX) do
                direction = is_descendant ? ' DESC' : ' ASC'

                aim_orders = [];
                aim_orders << @_ff_soft_delete + direction if has_soft_delete?
                aim_orders << @_ff_grove       + direction if has_grove?
                aim_orders << @_ff_depth       + direction if is_depth_index
                aim_orders << @_ff_queue       + direction

                order(aim_orders.join(', '))
              end

            scope :ff_required_columns_scope,
              ->(add_columns = nil) do
                columns = [@_id, @_ff_queue, @_ff_depth]
                columns << @_ff_grove if has_grove?

                columns += add_columns if add_columns.present?

                select(columns)
              end

            scope :ff_subtree_scope,
              ->(base_node, with_top = false, use_coalesce = false) do
                return nil if base_node.blank?

                ffqq = arel_table[@_ff_queue]
                ffdd = arel_table[@_ff_depth]
                ffgg = arel_table[@_ff_grove]

                compair = with_top ? :gteq : :gt
                aim_query = ff_usual_conditions_scope(base_node.ff_grove)
                    .where(ffqq.send(compair, base_node.ff_queue))

                if use_coalesce
                  # TODO: methodize
                  subquery = ff_create_subquery_string_to_find_tail_queue(base_node)
                  func_maker = Arel::Nodes::NamedFunction
                  coalesce_condition = func_maker.new('COALESCE', [subquery, QUEUE_MAX_VALUE])
                  aim_query.where!(ffqq.lteq(coalesce_condition))
                else
                  boundary_queue = ff_get_boundary_queue(base_node)
                  if boundary_queue.blank?
                    # need this conditions for leaves @dd = ffdd.
                    aim_query.where!(ffqq.lteq(QUEUE_MAX_VALUE))
                  else
                    aim_query.where!(ffqq.lt(boundary_queue))
                  end
                end

                aim_query
              end

            # boundary node onditions scope
            # tail node onditions scope
            # pre nodes conditions scope
          end

          def ff_usual_projection(grove_id = nil)
            res = arel_table.project()

            res = res.where(arel_table[@_ff_soft_delete].eq(ff_options[:enable_value])) \
                if has_soft_delete?

            if has_grove?
              ffgg = arel_table[@_ff_grove]
              if grove_id.present?
                # res = res.send :where, {@_ff_grove => grove_id}
                if grove_id.instance_of?(Array)
                  res = res.where(ffgg.in(grove_id))
                else
                  res = res.where(ffgg.eq(grove_id))
                end
              else
                res = res.where(ffgg.gteq(0)) \
                    if enable_grove_delete?
              end
            end

            res
          end

          def ff_create_usual_conditions_hash(grove_id = nil)
            res = {}
            res[:ff_soft_delete] = ff_options[:enable_value] \
                if has_soft_delete?

            if has_grove?
              if grove_id.present?
                res[:ff_grove] = grove_id
              else
                res['ff_grove >='] = 0 if enable_grove_delete?
              end
            end

            res
          end

          def ff_all_optional_columns(optional_columns = nil)
            optional_columns ||= column_names

            required_columns = [@_id, @_ff_grove, @_ff_depth, @_ff_queue]
            regexp_string = required_columns
                .map { |column| column.to_s }
                .join('|')
            delete_regexp = /#{regexp_string}/i

            # return value (must be Array).
            optional_columns.delete_if do |column|
              delete_regexp.match(column)
            end
          end

          def ff_create_subquery_string_to_find_tail_queue(aim_node)
            ffqq = arel_table[@_ff_queue]
            ffdd = arel_table[@_ff_depth]

            ff_usual_projection(aim_node.ff_grove)
                .project(ffqq.minimum.to_sql + " - 1 AS boundary_queue")
                .where(ffdd.lteq(aim_node.ff_depth))
                .where(ffqq.gt(aim_node.ff_queue))
          end
        # end of private
      end
    end
  end
end
