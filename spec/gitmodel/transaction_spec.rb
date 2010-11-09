require 'spec_helper'

describe GitModel::Transaction do

  describe '#execute' do
    it "yields to a given block" do
      m = mock("mock")
      m.should_receive(:a_method)
      GitModel::Transaction.new.execute do
        m.a_method
      end
    end

    describe "when called the first time" do
      it "creates a new Git index" do
        index = mock("index")
        index.stub!(:read_tree)
        index.stub!(:commit)
        Grit::Index.should_receive(:new).and_return(index)
        GitModel::Transaction.new.execute {}
      end

      it "commits after yielding" do
        index = mock("index")
        index.stub!(:read_tree)
        index.should_receive(:commit)
        Grit::Index.should_receive(:new).and_return(index)
        GitModel::Transaction.new.execute {}
      end

      it "can create the first commit in the repo" do
        GitModel::Transaction.new.execute do |t|
          t.index.add "foo", "foo"
        end
      end

      # TODO it "locks the branch while committing"

      # TODO it "merges commits from concurrent transactions"

    end

    describe "when called recursively" do

      it "re-uses the existing git index and doesn't commit" do
        index = mock("index")
        index.stub!(:read_tree)
        index.should_receive(:commit).once
        Grit::Index.should_receive(:new).and_return(index)
        GitModel::Transaction.new.execute do |t|
          t.execute {}
        end
      end

    end

  end

end
