module GitModel
  module Serialization
    class Yajl
      class << self
        def attributes_filename
          "attributes.json"
        end
        
        def encode(data)
          ::Yajl::Encoder.encode(data, nil, :pretty => true)
        end
      end
    end
  end
end