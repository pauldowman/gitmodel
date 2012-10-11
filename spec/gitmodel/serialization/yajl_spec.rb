require 'spec_helper'

RSpec.configure do |c|
  c.include RawData
end

describe GitModel::Serialization::Yajl do
  describe ".encode" do    
    it "should encode data as json" do
      data = {
        x: 1,
        y: "bob",
        z: [4,5,6]
      }
      GitModel::Serialization::Yajl.encode(data).should ==
        ::Yajl::Encoder.encode(data, nil, :pretty => true)
    end
  end
  
  context "set as GitModel serializer" do
    before do
      GitModel.serializer = GitModel::Serialization::Yajl
    end
  
  
    it "should use attributes.json as the attribute filename" do    
      GitModel.attributes_filename.should == "attributes.json"
    end
    
    it "should save attributes as json" do
      data = {
        x: 1,
        y: "bob",
        z: [4,5,6]
      }
    
      TestEntity.create!(:id => "foo", 
        :attributes => {:x => 1, :y => "bob", :z => [4,5,6]})
    
      last_saved_entity_attributes('foo').should == Yajl::Encoder.encode(data, nil, :pretty => true)
    end
  end
end