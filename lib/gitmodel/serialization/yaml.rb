module GitModel
  module Serialization
    class Yaml
      class << self
        def filename_extension
          "yaml"
        end
        
        def attributes_filename
          "attributes.#{filename_extension}"
        end
        
        def encode(data)
          data.to_hash.to_yaml
        end
      end
    end
  end
end