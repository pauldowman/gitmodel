require 'spec_helper'

RSpec.configure do |c|
  c.include RawData
end

describe GitModel::Serialization::Yaml do
  describe ".encode" do    
    it "should encode data as yaml" do
      data = {
        x: 1,
        y: "bob",
        z: [4,5,6]
      }
      GitModel::Serialization::Yaml.encode(data).should ==
        data.to_yaml
    end
  end
  
  context "set as GitModel serializer" do
    before do
      GitModel.serializer = GitModel::Serialization::Yaml
    end
  
  
    it "should use attributes.json as the attribute filename" do    
      GitModel.attributes_filename.should == "attributes.yaml"
    end
    
    
    it "should save attributes as yaml" do
      data = {
        'x' => 1,
        'y' => "bob",
        'z' => [4,5,6]
      }
    
      TestEntity.create!(:id => "foo", 
        :attributes => {:x => 1, :y => "bob", :z => [4,5,6]})
    
      last_saved_entity_attributes('foo').should == data.to_yaml
    end
  end
end