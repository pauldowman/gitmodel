require 'rubygems'
require 'bundler/setup'

require 'active_model'
require 'active_support/all' # TODO we don't really want all here, clean this up
require 'grit'
require 'json'
require 'lockfile'
require 'pp'

$:.unshift(File.dirname(__FILE__))
require 'gitmodel/errors'
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

  def self.last_commit(branch = nil)
    branch ||= default_branch
    # PERFORMANCE Cache this somewhere and update it on commit?
    # (Need separate instance per branch)

    return nil unless repo.commits(branch).any?

    # We should be able to use just repo.commits(branch).first here but
    # this is a workaround for this bug: 
    # http://github.com/mojombo/grit/issues/issue/38
    GitModel.repo.commits("#{branch}^..#{branch}").first || GitModel.repo.commits(branch).first
  end

  def self.current_tree(branch = nil)
    c = last_commit(branch)
    c ? c.tree : nil
  end

end
