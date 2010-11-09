require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe GitModel do

  describe "#last_commit" do

    it "returns nil if there are no commits" do
      GitModel.last_commit.should == nil
    end

    it "returns the most recent commit on a branch" do
      index = Grit::Index.new(GitModel.repo)
      head = GitModel.repo.commits.first
      index.read_tree head.to_s
      index.add "foo", "foo"
      sha = index.commit nil, nil, nil, nil, 'master'
            
      GitModel.last_commit.to_s.should == sha
    end

  end

  describe "#current_tree" do

    it "returns nil if there are no commits" do
      GitModel.current_tree.should == nil
    end

    it "returns the tree for the most recent commit on a branch" do
      last_commit = mock('last_commit')
      last_commit.should_receive(:tree).and_return("yay, a tree!")
      GitModel.should_receive(:last_commit).with('master').and_return(last_commit)
      GitModel.current_tree('master')
    end

  end

end

