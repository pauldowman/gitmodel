# coding: UTF-8

require 'rubygems'
require 'bundler/setup'

require 'active_model'
require 'active_support/all' # TODO we don't really want all here, clean this up
require 'dalli'
require 'grit'
require 'lockfile'
require 'pp'
require 'yajl'

$:.unshift(File.dirname(__FILE__))
require 'gitmodel/errors'
require 'gitmodel/index'
require 'gitmodel/persistable'
require 'gitmodel/transaction'

module GitModel

  # db_root must be an existing git repo. (It can be created with create_db!)
  # Bare repositories aren't supported yet, it must be a normal git repo with a
  # working directory and a '.git' subdirectory.
  mattr_accessor :db_root
  self.db_root = './gitmodel-data'

  mattr_accessor :default_branch
  self.default_branch = 'master'

  mattr_accessor :logger
  self.logger = ::Logger.new(STDERR)
  self.logger.level = ::Logger::WARN

  mattr_accessor :git_user_name
  mattr_accessor :git_user_email

  mattr_accessor :memcache_servers
  mattr_accessor :memcache_namespace

  def self.repo
    @@repo = Grit::Repo.new(GitModel.db_root)
  end

  # Create the database defined in db_root. Raises an exception if it exists.
  def self.create_db!
    raise "Database #{db_root} already exists!" if File.exist? db_root
    if db_root =~ /.+\.git/
      #logger.info "Creating database (bare): #{db_root}"
      #Grit::Repo.init_bare db_root
      logger.error "Bare repositories aren't supported yet"
    else
      logger.info "Creating database: #{db_root}"
      Grit::Repo.init db_root
    end
  end

  # Delete and re-create the database defined in db_root. Dangerous!
  def self.recreate_db!
    logger.info "Deleting database #{db_root}!!"
    FileUtils.rm_rf db_root
    create_db!
  end

  def self.last_commit(branch)
    cache(branch, 'last-commit') do
      unless repo.commits(branch).any?
        nil
      else
        # We should be able to use just repo.commits(branch).first here but
        # this is a workaround for this bug: 
        # http://github.com/mojombo/grit/issues/issue/38
        GitModel.repo.commits("#{branch}^..#{branch}").first || GitModel.repo.commits(branch).first
      end
    end
  end

  def self.current_tree(branch)
    c = last_commit(branch)
    c ? c.tree : nil
  end

  def self.index!(branch)
    dirs = (GitModel.current_tree(branch)).trees
    dirs.each do |dir|
      dir.name.classify.constantize.index!(branch)
    end
  end

  # If we're using memcached (i.e. the memcache_servers setting is not nil) and
  # the key exists in memcached, it's value will be returned and the block will
  # not be run.  If key does not exist in memcached, block will be executed,
  # it's value stored in memcached under key, and value will be returned.
  #
  # There's no need to sweep the cache because the SHA of the latest Git commit
  # is appended to the key, so any database change invalidates all cached
  # objects.
  def self.cache(branch, key, &block)
    key = "#{key}-#{head_sha(branch)}"
    value = nil
    if memcache_servers
      @@memcache ||= Dalli::Client.new memcache_servers, :namespace => "#{File.basename(db_root)}#{memcache_namespace.blank? ? '' : '-'}#{memcache_namespace}"
      value = @@memcache.get(key)
      if value.nil?
        logger.info("✗ memcache MISS for key #{key}")
        value = yield
        @@memcache.set(key, value)
      else
        logger.info("✔ memcache HIT for key #{key}")
      end
    else
      logger.debug("No memcache servers defined, not checking cache for key #{key}")
      value = yield
    end
    value
  end

  private

  # A more efficient way to get the SHA of the HEAD of the given branch
  def self.head_sha(branch_name)
    ref = File.join(repo.git.git_dir, "refs/heads/#{branch_name}")
    File.exist?(ref) ? File.read(ref).chomp : nil
  end
end
