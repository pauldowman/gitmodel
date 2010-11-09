module GitModel
  class Transaction

    attr_accessor :index
    attr_accessor :branch
    attr_accessor :commit_message

    def initialize(options = {})
      self.branch = options[:branch] || GitModel.default_branch
      self.commit_message = options[:commit_message]
    end

    def execute(&block)
      if index 
        # We're already in a transaction
        yield self
      else
        # For now there's a big ugly lock here, this will be fixed!
        # TODO move this lock around the commit only (need to make sure two
        # processes aren't updating refs/heads/<branch> at the same time) and
        # make concurrent transactions can work. This will require some merging
        # magic!
        lock do
          # We're not in a transaction, start a new one
          GitModel.logger.debug "Beginning transaction on #{branch}..."

          # Save the current head so that concurrent transactions can work. We need
          # to make sure the parent of this commit is the same SHA that this
          # index's tree is based on.
          parent = GitModel.last_commit(branch)

          self.index = Grit::Index.new(GitModel.repo)
          index.read_tree(parent.to_s)
          
          yield self

          committer = Grit::Actor.new(GitModel.git_user_name, GitModel.git_user_email)
          sha = index.commit(commit_message, parent ? [parent] : nil, committer, nil, branch)
          # TODO return false and log if anything went wrong with the commit

          GitModel.logger.debug "Finished transaction on #{branch}."

          return sha
        end
      end
    end

    # Wait until we can get an exclusive lock on the branch, then execute the
    # block.  We lock the branch by creating refs/heads/<branch>.lock, which
    # the git commands also seem to respect
    def lock(&block)
      lockfile = Lockfile.new File.join(GitModel.repo.path, 'refs/heads', branch + '.lock')
      begin
        lockfile.lock
        yield
      ensure
        lockfile.unlock
      end
    end

  end
end
