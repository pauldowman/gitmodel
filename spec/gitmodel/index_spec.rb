require 'spec_helper'

describe GitModel::Index do
  before(:each) do
    TestEntity.create!(:id => "foo", :attributes => {:x => 1, :y => 2})
    TestEntity.create!(:id => "bar", :attributes => {:x => 1, :y => 3})
    TestEntity.create!(:id => "baz", :attributes => {:x => 2, :y => 2})

    @i = GitModel::Index.new(TestEntity)
    @i.generate!
  end

  it "has a hash for each attribute of the model" do
    @i.attr_index(:x).should be_a(Hash)
  end

  it "knows the id's of all instances with a given value for an attribute" do
    @i.attr_index(:x)[1].should == SortedSet.new(["foo", "bar"])
    @i.attr_index(:x)[2].should == SortedSet.new(["baz"])
    @i.attr_index(:y)[2].should == SortedSet.new(["foo", "baz"])
  end

  it "can regenerate itself" do
    @i.attr_index(:x).clear
    @i.attr_index(:x).should be_empty
    @i.generate!
    @i.attr_index(:x).should == {1 => SortedSet.new(["foo", "bar"]), 2 => SortedSet.new(["baz"])}
  end

  it "knows it's filename" do
    @i.filename.should == "test_entities/_indexes.json"
  end

  it "can save itself to a JSON file" do
    @i.save
    json = <<-END.strip
[
  [
    "x",
    [
      [
        1,
        [
          "bar",
          "foo"
        ]
      ],
      [
        2,
        [
          "baz"
        ]
      ]
    ]
  ],
  [
    "y",
    [
      [
        3,
        [
          "bar"
        ]
      ],
      [
        2,
        [
          "baz",
          "foo"
        ]
      ]
    ]
  ]
]
END
    repo = Grit::Repo.new(GitModel.db_root)
    # We should be able to use just repo.commits.first here but
    # this is a workaround for this bug: 
    # http://github.com/mojombo/grit/issues/issue/38
    (repo.commits("master^..master").first.tree / @i.filename).data.should == json
  end

  it "can save and load itself from a file" do
    @i.save
    @i.attr_index(:x).clear
    @i.load
    @i.attr_index(:x).should == {1 => SortedSet.new(["foo", "bar"]), 2 => SortedSet.new(["baz"])}
  end

  describe "#attr_index" do
    it "loads itself" do
      i = GitModel::Index.new(TestEntity)
      i.should_receive(:load)
      i.attr_index(:foo)
    end

    describe "with an index file already created" do
      before(:each) { @i.save }

      it "loads itself from file" do
        i = GitModel::Index.new(TestEntity)
        i.should_not_receive(:generate!)
        i.attr_index(:foo)
      end
    end
  end

end
