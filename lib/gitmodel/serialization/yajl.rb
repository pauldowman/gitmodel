module GitModel
  module Serialization
    class Yajl
      class << self
        def filename_extension
          "json"
        end
        
        def attributes_filename
          "attributes.#{filename_extension}"
        end
        
        def encode(data)
          ::Yajl::Encoder.encode(data, nil, :pretty => true)
        end
      end
    end
  end
end