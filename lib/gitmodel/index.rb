module GitModel
  class Index
    def initialize(model_class)
      @model_class = model_class
    end

    def generate!(branch)
      GitModel.logger.debug "Generating indexes for #{@model_class}"
      # TODO it sucks to load every instance here, optimize later
      @indexes = {}
      @model_class.find_all(:branch => branch).each do |o|
        o.attributes.each do |attr, value|
          @indexes[attr] ||= {}
          @indexes[attr][value] ||= SortedSet.new
          @indexes[attr][value] << o.id
        end
      end
    end

    def attr_index(attr)
      self.load unless @indexes
      unless @indexes # this is just so that we can stub self.load in tests
        nil
      else
        @indexes[attr.to_s] || {}
      end
    end

    def filename
      File.join(@model_class.db_subdir, '_indexes.json')
    end

    def generated?(branch = GitModel.default_branch)
      (GitModel.current_tree(branch) / filename) ? true : false
    end

    def save(options = {})
      GitModel.logger.debug "Saving indexes for #{@model_class}..."
      transaction = options.delete(:transaction) || GitModel::Transaction.new(options) 
      branch = transaction.branch || options.delete(:branch) || GitModel.default_branch
      result = transaction.execute do |t|
        # convert to array because JSON hash keys must be strings
        data = []
        @indexes.each do |attr,values|
          values_and_ids = []
          values.each do |value, ids|
            values_and_ids << [value, ids.to_a]
          end
          data << [attr,values_and_ids]
        end
        data = Yajl::Encoder.encode(data, nil, :pretty => true)
        t.index.add(filename, data)
      end
    end

    def load(branch = GitModel.default_branch)
      @indexes = GitModel.cache(branch, "#{@model_class.db_subdir}-index-load") do
        unless generated?(branch)
          GitModel.logger.debug "No index generated for #{@model_class}, on branch #{branch}, not loading."
        else
          GitModel.logger.debug "Loading indexes for #{@model_class}..."
          indexes = {}
          blob = GitModel.current_tree(branch) / filename
          
          data = Yajl::Parser.parse(blob.data)
          data.each do |attr_and_values|
            attr = attr_and_values[0]
            values = {}
            attr_and_values[1].each do |value_and_ids|
              value = value_and_ids[0]
              ids = SortedSet.new(value_and_ids[1])
              values[value] = ids
            end
            indexes[attr] = values
          end
        end
        indexes
      end
    end

  end
end
