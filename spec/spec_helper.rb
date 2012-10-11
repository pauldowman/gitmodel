require 'rspec'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'gitmodel'

Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each {|f| require f}

RSpec.configure do |c|
  c.mock_with :rspec
end

class TestEntity
  include GitModel::Persistable
end
class TestEntity2
  include GitModel::Persistable
end

#GitModel.logger.level = ::Logger::DEBUG
GitModel.memcache_servers = ['localhost']

module RawData
  def last_saved_entity_attributes(id)
    repo = Grit::Repo.new(GitModel.db_root)
    (repo.commits.first.tree / File.join(TestEntity.db_subdir, id, 'attributes.json')).data
  end
end