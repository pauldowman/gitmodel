module GitModel
  module Persistable

    def self.included(base)
      base.class_eval do
         
        extend ActiveModel::Callbacks
        extend ActiveModel::Naming
        include ActiveModel::Validations
        include ActiveModel::Dirty
        include ActiveModel::Observing
        include ActiveModel::Translation

        define_model_callbacks :initialize, :find, :touch, :only => :after
        define_model_callbacks :save, :create, :update, :destroy

        cattr_accessor :index, true
        self.index = GitModel::Index.new(self)
      end

      base.extend(ClassMethods)
    end
    
  
    def initialize(args = {})
      _run_initialize_callbacks do
        @new_record = true 
        self.attributes = {}
        self.blobs = {}
        args.each do |k,v|
          self.send("#{k}=".to_sym, v)
        end
      end
    end

    def to_model
      self
    end

    def to_key
      id ? [id] : nil
    end

    def to_param
      id && id.to_s
    end
      
    def id
      @id
    end
  
    def id=(string)
      # TODO ensure is valid as a filename
      @id = string
    end

    # Get the location of the record relative to the repository's root.
    #
    # It is determined by appending the name of the directory containing
    # the record with the record's +id+.
    def path
      @path ||= File.join(self.class.db_subdir, self.id)
    end

    # Get the branch that the record was last loaded from or was last
    # saved on.
    #
    # The branch specified in the +GitModel+ config is used by default.
    # Typically, the branch is 'master'.
    def branch
      @branch ||= GitModel.default_branch
    end

    def attributes
      @attributes
    end
  
    def attributes=(new_attributes, guard_protected_attributes = true)
      @attributes = HashWithIndifferentAccess.new
      if new_attributes
        new_attributes.each {|k,v| @attributes[k] = v}
      end
    end

    def blobs
      @blobs
    end
  
    def blobs=(new_blobs)
      @blobs = HashWithIndifferentAccess.new
      if new_blobs
        new_blobs.each {|k,v| @blobs[k] = v}
      end
    end

    def new_record?
      @new_record || false
    end

    def persisted?
      !new_record?
    end

    # Valid options are:
    #   :transaction
    #   OR:
    #   :branch
    #   :commit_message
    # Returns false if validations failed, otherwise returns the SHA of the commit
    def save(options = {})
      _run_save_callbacks do 
        raise GitModel::NullId unless self.id

        if new_record?
          raise GitModel::RecordExists if self.class.exists?(self.id)
        else
          raise GitModel::RecordDoesntExist unless self.class.exists?(self.id)
        end

        GitModel.logger.debug "Saving #{self.class.name} with id: #{id}"

        dir = File.join(self.class.db_subdir, self.id)

        transaction = options.delete(:transaction) || GitModel::Transaction.new(options) 
        result = transaction.execute do |t|
          # Write the attributes to the attributes file
          t.index.add(File.join(dir, 'attributes.json'), Yajl::Encoder.encode(attributes, nil, :pretty => true))

          # Write the blob files
          blobs.each do |name, data|
            t.index.add(File.join(dir, name), data)
          end
        end

        result
      end
    end

    # Same as #save but raises an exception on error
    def save!(options = {})
      save(options) || raise(GitModel::RecordNotSaved)
    end

    def delete(options = {})
      freeze
      self.class.delete(id, options)
    end

    def to_s
      "#<#{self.class.name}:#{__id__} id=#{id}, attributes=#{attributes.inspect}, blobs.keys=#{blobs.keys.inspect}>"
    end


    private

    def load(dir, branch)
      _run_find_callbacks do
        # remove dangerous ".."
        # todo find a better way to ensure path is safe
        dir.gsub!(/\.\./, '')

        raise GitModel::RecordNotFound if GitModel.current_tree(branch).nil?

        self.id = File.basename(dir)
        @new_record = false
        
        GitModel.logger.debug "Loading #{self.class.name} with id: #{id}"

        # load the attributes
        object = GitModel.current_tree(branch) / File.join(dir, 'attributes.json')
        raise GitModel::RecordNotFound if object.nil?

        self.attributes = Yajl::Parser.parse(object.data)

        # load all other non-hidden files in the dir as blobs
        blobs = (GitModel.current_tree(branch) / dir).blobs.reject{|b| b.name[0] == '.' || b.name == 'attributes.json'}
        blobs.each do |b|
          self.blobs[b.name] = b.data
        end
      end
    end


    module ClassMethods

      def db_subdir
        self.to_s.tableize
      end

      def attribute(name, options = {})
        default = options[:default]
        self.class_eval <<-EOF
          def #{name}; attributes[:#{name}] || #{default.inspect}; end
          def #{name}=(value); attributes[:#{name}] = value; end
        EOF
      end

      def blob(name, options = {})
        self.class_eval <<-EOF
          def #{name}; blobs[:#{name}]; end
          def #{name}=(value); blobs[:#{name}] = value; end
        EOF
      end

      def find(id, branch = GitModel.default_branch)
        GitModel.logger.debug "Finding #{name} with id: #{id}"
        result = GitModel.cache(branch, "#{db_subdir}-find-#{id}") do
          o = new
          dir = File.join(db_subdir, id)
          o.send :load, dir, branch
          o
        end
        return result
      end

      def exists?(id, branch = GitModel.default_branch)
        GitModel.logger.debug "Checking existence of #{name} with id: #{id}"
        result = GitModel.cache(branch, "#{db_subdir}-exists-#{id}") do
          GitModel.repo.commits.any? && !(GitModel.current_tree(branch) / File.join(db_subdir, id, 'attributes.json')).nil?
        end
        return result
      end

      # TODO document conditions
      # :branch
      # :cache_key
      # :order_by
      # :order
      # any model attribute
      def find_all(conditions = {})
        branch = conditions.delete(:branch) || GitModel.default_branch
        # TODO Refactor this spaghetti
        GitModel.logger.debug "Finding all #{name.pluralize} with conditions: #{conditions.inspect}"
        cache_key = "#{db_subdir}-find_all-#{format_conditions_hash_for_cache_key(conditions)}"
        cached_results = GitModel.cache(branch, cache_key) do
          current_tree = GitModel.current_tree(branch)
          unless current_tree
            []
          else
            order = conditions.delete(:order) || :asc
            order_by = conditions.delete(:order_by) || :id
            limit = conditions.delete(:limit)

            matching_ids = []
            if conditions.empty?  # load all objects
              trees = (current_tree / db_subdir).trees
              trees.each do |t|
                matching_ids << t.name if t.blobs.any?
              end
            else # only load objects that match conditions
              matching_ids_for_condition = {}
              conditions.each do |k,v|
                matching_ids_for_condition[k] = []
                if k == :id # id isn't indexed
                  if v.is_a?(Proc)
                    trees = (current_tree / db_subdir).trees
                    trees.each do |t|
                      matching_ids_for_condition[k] << t.name if t.blobs.any? && v.call(t.name)
                    end
                  else
                    # an unlikely use case but supporting it for completeness
                    matching_ids_for_condition[k] << v if (current_tree / db_subdir / v)
                  end
                else
                  raise GitModel::IndexRequired unless index.generated?
                  attr_index = index.attr_index(k)
                  if v.is_a?(Proc)
                    attr_index.each do |value, ids|
                      matching_ids_for_condition[k] += ids.to_a if v.call(value)
                    end
                  else
                    matching_ids_for_condition[k] += attr_index[v].to_a
                  end
                end
              end
              matching_ids += matching_ids_for_condition.values.inject{|memo, obj| memo & obj}
            end

            results = nil
            if order_by != :id
              GitModel.logger.warn "Ordering by an attribute other than id requires loading all matching objects before applying limit, this will be slow" if limit
              results = matching_ids.map{|k| find(k)}

              if order == :asc
                results = results.sort{|a,b| a.send(order_by) <=> b.send(order_by)}
              elsif order == :desc
                results = results.sort{|b,a| a.send(order_by) <=> b.send(order_by)}
              else
                raise GitModel::InvalidParams("invalid order: '#{order}'")
              end

              if limit
                results = results[0, limit]
              end
            else
              if order == :asc
                matching_ids = matching_ids.sort{|a,b| a <=> b}
              elsif order == :desc
                matching_ids = matching_ids.sort{|b,a| a <=> b}
              else
                raise GitModel::InvalidParams("invalid order: '#{order}'")
              end
              if limit

                matching_ids = matching_ids[0, limit]
              end
              results = matching_ids.map{|k| find(k)}
            end

            results
          end
        end # cached block
        return cached_results
      end

      def all_values_for_attr(attr)
        attr_index = index.attr_index(attr.to_s)
        values = attr_index ? attr_index.keys : []
      end

      def create(args)
        if args.is_a?(Array)
          args.map{|arg| create(arg)}
        else
          o = self.new(args)
          o.save
        end
        return o
      end

      def create!(args)
        if args.is_a?(Array)
          args.map{|arg| create!(arg)}
        else
          o = self.new(args)
          o.save!
        end
        return o
      end

      def delete(id, options = {})
        GitModel.logger.debug "Deleting #{name} with id: #{id}"
        path = File.join(db_subdir, id)
        transaction = options.delete(:transaction) || GitModel::Transaction.new(options) 
        result = transaction.execute do |t|
          branch = t.branch || options[:branch] || GitModel.default_branch
          delete_tree(path, t.index, branch, options)
        end
      end

      def delete_all(options = {})
        GitModel.logger.debug "Deleting all #{name.pluralize}"
        transaction = options.delete(:transaction) || GitModel::Transaction.new(options) 
        result = transaction.execute do |t|
          branch = t.branch || options[:branch] || GitModel.default_branch
          delete_tree(db_subdir, t.index, branch, options)
        end
      end

      def index!(branch)
        index.generate!(branch)
        index.save(:branch => branch)
      end


      private

      def delete_tree(path, index, branch, options = {})
        # This leaves a bunch of empty sub-trees, there must be a way to just
        # replace the tree to be deleted with an empty tree that doesn't even
        # reference the sub-trees.
        current = index.tree
        path.split('/').each do |dir|
          current[dir] ||= {}
          current = current[dir]
        end

        build_tree_hash(current, (index.current_tree / path))
      end

      # recusively build the hash representing the objects that grit will commit
      def build_tree_hash(hash, tree)
        tree.blobs.each do |b|
          hash[b.name] = false
        end
        tree.trees.each do |t|
          hash[t.name] = {}
          build_tree_hash(hash[t.name], t)
        end
        return hash
      end

      def format_conditions_hash_for_cache_key(hash)
        # allow setting an explicit cache key, mostly because Proc.hash is
        # usually different even with the same code and same parameters
        cache_key = hash.delete(:cache_key)

        unless cache_key
          cache_key = ""
          hash.inject('') do |s,kv|
            key = kv[0]
            val = kv[1]
            if val.is_a?(Proc)
              val = "proc-#{val.hash}"
            end
            cache_key += "#{key}:#{val};"
          end
        end
        cache_key
      end

    end # module ClassMethods
    
  end # module Persistable
end # module GitModel

