module Datasource
  class CollectionContext
    attr_reader :scope, :all_models, :datasource, :datasource_class, :params, :loaded_values

    def initialize(scope, collection, datasource, params)
      @scope = scope
      @all_models = collection
      @datasource = datasource
      @datasource_class = datasource.class
      @params = params
      @loaded_values = {}
    end

    def models
      return @models if @models

      @model_ids = []
      @models = all_models.select do |model|
        id = model.send(@datasource_class.primary_key)
        @model_ids << id
        id
      end
    end

    def model_ids
      return @model_ids if @model_ids
      models
      @model_ids
    end
    alias_method :ids, :model_ids
  end
end
