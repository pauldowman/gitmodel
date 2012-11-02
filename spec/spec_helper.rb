require 'rspec'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'gitmodel'

Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each {|f| require f}

RSpec.configure do |c|
  c.mock_with :rspec
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true
  c.treat_symbols_as_metadata_keys_with_true_values = true
  c.order = :random
end

class TestEntity
  include GitModel::Persistable
end
class TestEntity2
  include GitModel::Persistable
end

#GitModel.logger.level = ::Logger::DEBUG
GitModel.memcache_servers = ['localhost']
