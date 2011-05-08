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
          # NOTE: using the redundant attributes.to_hash to work around a bug in
          # active_support 3.0.4, remove when
          # JSON.generate(HashWithIndifferentAccess.new) no longer fails.
          # pretty_generate so that it's more mergeable by Git
          t.index.add(File.join(dir, 'attributes.json'), JSON.pretty_generate(attributes.to_hash))

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

    def load(dir)
      _run_find_callbacks do
        # remove dangerous ".."
        # todo find a better way to ensure path is safe
        dir.gsub!(/\.\./, '')

        raise GitModel::RecordNotFound if GitModel.current_tree.nil?

        self.id = File.basename(dir)
        @new_record = false
        
        GitModel.logger.debug "Loading #{self.class.name} with id: #{id}"

        # load the attributes
        object = GitModel.current_tree / File.join(dir, 'attributes.json')
        raise GitModel::RecordNotFound if object.nil?

        self.attributes = JSON.parse(object.data, :max_nesting => false)

        # load all other non-hidden files in the dir as blobs
        blobs = (GitModel.current_tree / dir).blobs.reject{|b| b.name[0] == '.' || b.name == 'attributes.json'}
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

      def find(id)
        GitModel.logger.debug "Finding #{name} with id: #{id}"
        o = new
        dir = File.join(db_subdir, id)
        o.send :load, dir
        return o
      end

      def exists?(id)
        GitModel.logger.debug "Checking existence of #{name} with id: #{id}"
        GitModel.repo.commits.any? && !(GitModel.current_tree / File.join(db_subdir, id, 'attributes.json')).nil?
      end

      def find_all(conditions = {})
        GitModel.logger.debug "Finding all #{name.pluralize} with conditions: #{conditions.inspect}"
        results = []
        return results unless GitModel.current_tree
        dirs = (GitModel.current_tree / db_subdir).trees
        dirs.each do |dir|
          if dir.blobs.any?
            o = new
            o.send :load, File.join(db_subdir, dir.name)
            results << o
          end
        end

        return results
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
          delete_tree(path, t.index, options)
        end
      end

      def delete_all(options = {})
        GitModel.logger.debug "Deleting all #{name.pluralize}"
        transaction = options.delete(:transaction) || GitModel::Transaction.new(options) 
        result = transaction.execute do |t|
          delete_tree(db_subdir, t.index, options)
        end
      end


      private

      def delete_tree(path, index, options = {})
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

    end # module ClassMethods
    
  end # module Persistable
end # module GitModel

