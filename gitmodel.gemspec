Gem::Specification.new do |s|
  s.name = 'gitmodel'
  s.version = '0.0.8'
  s.platform    = Gem::Platform::RUBY

  s.authors = ["Paul Dowman"]
  s.email = 'paul@pauldowman.com'
  s.homepage = 'http://github.com/pauldowman/gitmodel'

  s.summary = %q{An ActiveModel-compliant persistence framework for Ruby that uses Git for versioning and remote syncing.}
  s.description = <<-DESC.strip.gsub(/\n\s+/, " ")
    GitModel persists Ruby objects using Git as a data storage engine. It's an
    ActiveModel implementation so it works stand-alone or in Rails 3 as a drop-in
    replacement for ActiveRecord or DataMapper.  Because the database is a Git
    repository it can be synced across multiple machines, manipulated with standard
    Git client tools, can be branched and merged, and of course keeps the history
    of all changes.
  DESC

  s.add_dependency 'activemodel', '>= 3.0.1'
  s.add_dependency 'activesupport', '>= 3.0.1'
  s.add_dependency 'dalli'
  s.add_dependency 'grit', '>= 2.3.0'
  s.add_dependency 'lockfile', '>= 1.4.3'
  s.add_dependency 'rake'
  s.add_dependency 'yajl-ruby', '>= 0.8.2'

  s.add_development_dependency 'ZenTest', '>= 4.4.0'
  s.add_development_dependency 'autotest', '>= 4.4.1'
  s.add_development_dependency 'rspec', '>= 2.0.1'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
end

