module Datasource
  class CollectionContext
    attr_reader :scope, :models, :datasource, :datasource_class, :params, :loaded_values

    def initialize(scope, collection, datasource, params)
      @scope = scope
      @models = collection
      @datasource = datasource
      @datasource_class = datasource.class
      @params = params
      @loaded_values = {}
    end

    def model_ids
      @model_ids ||= @models.map(&@datasource_class.primary_key)
    end
    alias_method :ids, :model_ids
  end
end
