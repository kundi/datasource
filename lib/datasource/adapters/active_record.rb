require 'set'
require 'active_support/concern'

module Datasource
  module Adapters
    module ActiveRecord
      module ScopeExtensions
        def self.extended(mod)
          mod.instance_exec do
            @datasource_info ||= { select: [], params: [] }
          end
        end

        def datasource_get(key)
          @datasource_info[key]
        end

        def datasource_set(hash)
          @datasource_info.merge!(hash)
          self
        end

        def datasource_select(*args)
          @datasource_info[:select] += args
          self
        end

        def datasource_params(*args)
          @datasource_info[:params] += args
          self
        end

        def get_datasource
          klass = @datasource_info[:datasource_class]
          datasource = klass.new(self)
          datasource.select(*@datasource_info[:select])
          datasource.params(*@datasource_info[:params])
          if @datasource_info[:serializer_class]
            select = []
            @datasource_info[:serializer_class].datasource_adapter.to_datasource_select(select, klass.orm_klass, @datasource_info[:serializer_class], nil, datasource.adapter, datasource)

            datasource.select(*select)
          end
          datasource
        end

      private
        def exec_queries
          if @datasource_info[:datasource_class]
            datasource = get_datasource

            Datasource.logger.debug { "exec_queries expose_attributes: #{datasource.expose_attributes.inspect}" }
            Datasource.logger.debug { "exec_queries expose_associations: #{datasource.expose_associations.inspect}" }

            @loaded = true
            @records = datasource.results
          else
            super
          end
        end
      end

      module Model
        extend ActiveSupport::Concern

        included do
          attr_accessor :_datasource_loaded, :_datasource_instance
        end

        def for_serializer(serializer = nil)
          scope = self.class.for_serializer(serializer)

          pk = scope.datasource_get(:datasource_class).primary_key.to_sym
          if self_pk = send(pk)
            scope = scope.where(pk => self_pk)
          else
            scope = scope.none
          end

          scope = yield(scope) if block_given?

          datasource = scope.get_datasource
          if datasource.can_upgrade?(self)
            datasource.upgrade_records(self).first
          else
            scope.first
          end
        end

        module ClassMethods
          def for_serializer(serializer_class = nil)
            serializer_class ||=
              Datasource::Base.default_consumer_adapter.get_serializer_for(
                Adapters::ActiveRecord.scope_to_class(all))
            scope = scope_with_datasource_ext(serializer_class.use_datasource)
            scope.datasource_set(serializer_class: serializer_class)
          end

          def with_datasource(datasource_class = nil)
            scope_with_datasource_ext(datasource_class)
          end

          def default_datasource
            @default_datasource ||= begin
              "#{name}Datasource".constantize
            rescue NameError
              Datasource::From(self)
            end
          end

          def datasource_module(&block)
            default_datasource.instance_exec(&block)
          end

        private
          def scope_with_datasource_ext(datasource_class = nil)
            if all.respond_to?(:datasource_set)
              if datasource_class
                all.datasource_set(datasource_class: datasource_class)
              else
                all
              end
            else
              datasource_class ||= default_datasource

              all.extending(ScopeExtensions)
              .datasource_set(datasource_class: datasource_class)
            end
          end
        end
      end

    module_function
      def association_reflection(klass, name)
        if reflection = klass.reflect_on_association(name)
          {
            klass: reflection.klass,
            macro: reflection.macro,
            foreign_key: reflection.try(:foreign_key)
          }
        end
      end

      def get_table_name(klass)
        klass.table_name.to_sym
      end

      def is_scope?(obj)
        obj.kind_of?(::ActiveRecord::Relation)
      end

      def scope_to_class(scope)
        scope.klass
      end

      def scope_loaded?(scope)
        scope.loaded?
      end

      def scope_to_records(scope)
        scope.to_a
      end

      def has_attribute?(record, name)
        record.attributes.key?(name.to_s)
      end

      def association_klass(reflection)
        if reflection.macro == :belongs_to && reflection.options[:polymorphic]
          fail Datasource::Error, "polymorphic belongs_to not supported, write custom loader"
        else
          reflection.klass
        end
      end

      def association_loaded?(records, name, assoc_select)
        if records.first.association(name).loaded?
          all_loaded = records.all? { |record| record.association(name).loaded? }
          if assoc_select == ["*"]
            all_loaded
          elsif all_loaded
            records.all? do |record|
              assoc_sample = Array(record.send(name)).first
              assoc_sample.nil? || assoc_sample._datasource_instance
            end
          else
            false
          end
        else
          false
        end
      end

      def load_association(records, name, assoc_select, params)
        return if records.empty?
        name = name.to_sym
        klass = records.first.class
        if reflection = klass.reflect_on_association(name)
          assoc_class = association_klass(reflection)
          datasource_class = assoc_class.default_datasource

          scope = assoc_class.all
          datasource = datasource_class.new(scope)
          assoc_select_attributes = assoc_select.reject { |att| att.kind_of?(Hash) }
          assoc_select_associations = assoc_select.inject({}) do |hash, att|
            hash.deep_merge!(att) if att.kind_of?(Hash)
            hash
          end
          Datasource::Base.reflection_select(association_reflection(klass, name), [], assoc_select_attributes)
          datasource.params(params)

          Datasource.logger.debug { "load_association #{records.first.try!(:class)} #{name}: #{assoc_select_attributes.inspect}" }
          datasource.select(*assoc_select_attributes)
          select_values = datasource.get_select_values

          # TODO: manually load associations, and load them all at once for
          # nested associations, eg. in following, load all Users in 1 query:
          # {"user"=>["*"], "players"=>["*"], "picked_players"=>["*",
          # {:position=>["*"]}], "parent_picked_team"=>["*", {:user=>["*"]}]}
          begin
            ::ActiveRecord::Associations::Preloader
              .new.preload(records, name, assoc_class.select(*select_values))
          rescue ArgumentError
            ::ActiveRecord::Associations::Preloader
              .new(records, name, assoc_class.select(*select_values)).run
          end

          assoc_records = records.flat_map { |record| record.send(name) }.compact
          unless assoc_records.empty?
            if Datasource.logger.info? && !assoc_select_associations.empty?
              Datasource.logger.info { "Loading associations " + assoc_select_associations.keys.map(&:to_s).join(", ") + " for #{assoc_records.first.try!(:class)}s" }
            end
            assoc_select_associations.each_pair do |assoc_name, assoc_select|
              Datasource.logger.debug { "load_association nested association #{assoc_name}: #{assoc_select.inspect}" }
              load_association(assoc_records, assoc_name, assoc_select, params)
            end
            datasource.results(assoc_records)
          end
        end
      rescue Exception => ex
        if ex.is_a?(SystemStackError) || ex.is_a?(Datasource::RecursionError)
          fail Datasource::RecursionError, "recursive association (involving #{name})"
        else
          raise
        end
      end

      def to_query(ds)
        ::ActiveRecord::Base.uncached do
          ds.scope.select(*ds.get_select_values).to_sql
        end
      end

      def select_scope(ds)
        ds.scope.select(*ds.get_select_values)
      end

      def upgrade_records(ds, records)
        Datasource.logger.debug { "Upgrading records #{records.map(&:class).map(&:name).join(', ')}" }
        load_associations(ds, records)
        ds.results(records)
      end

      def load_associations(ds, records)
        if Datasource.logger.info? && !ds.expose_associations.empty?
          Datasource.logger.info { "Loading associations " + ds.expose_associations.keys.map(&:to_s).join(", ") + " for #{records.first.try!(:class)}s" }
        end
        Datasource.logger.debug { "load_associations (#{records.size} #{records.first.try!(:class)}): #{ds.expose_associations.inspect}" }
        ds.expose_associations.each_pair do |assoc_name, assoc_select|
          load_association(records, assoc_name, assoc_select, ds.params)
        end
      end

      def get_rows(ds)
        append_select = []
        ds.expose_associations.each_pair do |assoc_name, assoc_select|
          if reflection = association_reflection(ds.class.orm_klass, assoc_name.to_sym)
            Datasource::Base.reflection_select(reflection, append_select, [])
          end
        end
        ds.select(*append_select)

        scope = select_scope(ds)
        if scope.respond_to?(:datasource_set)
          scope = scope.spawn.datasource_set(datasource_class: nil)
        end
        scope.includes_values = []
        scope.to_a.tap do |records|
          load_associations(ds, records)
        end
      end

      def primary_scope_table(ds)
        ds.scope.klass.table_name
      end

      def ensure_table_join!(ds, name, att)
        join_value = ds.scope.joins_values.find do |value|
          if value.is_a?(Symbol)
            value.to_s == att[:name]
          elsif value.is_a?(String)
            if value =~ /join (\w+)/i
              $1 == att[:name]
            end
          end
        end
        fail Datasource::Error, "given scope does not join on #{name}, but it is required by #{att[:name]}" unless join_value
      end

      module DatasourceGenerator
        def From(klass)
          if klass.ancestors.include?(::ActiveRecord::Base)
            Class.new(Datasource::Base) do
              attributes *klass.column_names
              associations *klass.reflections.keys

              define_singleton_method(:orm_klass) do
                klass
              end

              define_singleton_method(:default_adapter) do
                Datasource::Adapters::ActiveRecord
              end

              define_singleton_method(:primary_key) do
                klass.primary_key.to_sym
              end
            end
          else
            super if defined?(super)
          end
        end
      end
    end
  end

  extend Adapters::ActiveRecord::DatasourceGenerator
end

if not(::ActiveRecord::Base.respond_to?(:datasource_module))
  class ::ActiveRecord::Base
    include Datasource::Adapters::ActiveRecord::Model
  end
end
