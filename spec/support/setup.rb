GitModel.db_root = '/tmp/gitmodel-test-data'
GitModel.git_user_name = 'GitModel Test'
GitModel.git_user_email = 'foo@bar.com'

RSpec.configure do |config|
  config.expect_with :rspec, :stdlib
  config.before(:each) do
    GitModel.recreate_db!
  end
end

