GitModel: distributed, versioned NoSQL for Ruby
---------------------------------------------------

_http://github.com/pauldowman/gitmodel_

GitModel is an
[ActiveModel](http://yehudakatz.com/2010/01/10/activemodel-make-any-ruby-object-feel-like-activerecord/)-compliant
persistence framework for Ruby that uses [Git](http://git-scm.com/) for
versioning and remote syncing.

GitModel persists Ruby objects using Git as a data storage engine. It's an
ActiveModel implementation so it works stand-alone or in Rails 3 as a drop-in
replacement for ActiveRecord or DataMapper. 

Because the database is a Git repository it can be synced across multiple
machines, manipulated with standard Git client tools, can be branched and
merged, and of course keeps the history of all changes.


Why it's awesome
----------------

* Schema-less NoSQL data store
* Each record is a normal Ruby object, attributes are any Ruby type or large
  chunks of binary data
* Never lose data, history is kept forever and can be restored simply using
  standard Git tools
* Branch and merge your production data 
  * GitModel can actually work with different branches
  * Branch or tag snapshots of your data
  * Experiment on production data using branches, for example to test a
    migration
* Distributed (synced using standard Git push/pull)
* All ActiveModel 
* Transactions
* Metadata for all database changes (Git commit messages, date & time, etc.)
* In order to be easily human-editable, the database is simply files and
  directores stored in a Git repository.  GitModel uses the Git repo directly
  (rather than Git's checked-out "working copy") but you can do a "git
  checkout" to view and manipulate the database contents, and then "git commit"
* Test-driven development and excellent test coverage
* Clean and easy-to-use API


Status
------

_It is not yet production ready but I'm working on it. Please feel free to
contribute tests and/or code to help!_

I will attempt to follow [Semantic Versioning](http://semver.org/) so 1.0.0
will be considered the first stable release, until then the API may change at
any time.

See the "To do" section below for details, but the main thing that needs
finishing is support for querying. Right now you can find an instance by it's
id, but there is incomplete support (90% complete) for querying, e.g.:

```ruby
Post.find(:category => 'ruby', :date => lambda{|d| d > 1.month.ago} :order_by => :date, :order => :asc, :limit => 5)
```

This includes support for indexing all attributes so that queries don't need to
load every object.


Installation
------------

It's available as a [RubyGem](https://rubygems.org/gems/gitmodel):

    > gem install gitmodel


Usage
-----

```ruby
GitModel.db_root = '/tmp/gitmodel-data'
GitModel.create_db!

class Post
  include GitModel::Persistable

  attribute :title
  attribute :body
  attribute :categories, :default => []
  attribute :allow_comments, :default => true

  blob :image
end

p1 = Post.new(:id => 'lessons-learned', :title => 'Lessons learned', :body => '...')
p1.image = some_binary_data
p1.save!

p = Post.find('lessons-learned')

p2 = Post.new(:id => 'hotdog-eating-contest', :title => 'I won!')
p2.body = 'This weekend I won a hotdog eating contest!'
p2.image = some_binary_data
p2.blobs['hotdogs.jpg'] = some_binary_data
p2.blobs['the-aftermath.jpg'] = some_binary_data
p2.save!

p3 = Post.create!(:id => 'running-with-scissors', :title => 'Running with scissors', :body => '...')

p4 = Post.find('running-with-scissors')

class Comment
  include GitModel::Persistable
  attribute :text
end

c1 = Comment.create!(:id => '2010-01-03-328', :text => '...')
c2 = Comment.create!(:id => '2010-05-29-742', :text => '...')
```


An example of a project that uses GitModel is [Balisong](https://github.com/pauldowman/balisong), a blogging app for coders (but it doesn't save objects to the data store. It's read-only so far, assuming that posts will be edited with a text editor).


Database file structure
-----------------------

The database is stored in a human-editable format. Simply do "git checkout -f"
and you'll see directories and files.

Each type of object is stored in a top-level directory (this is analogous to
ActiveRecord tables), and each object is stored in a subdirectory which is
named using the object's id (i.e. the primary key). Attributes that are Ruby
types (strings, numbers, hashes, arrays, whatever) are stored in a file named
attributes.json and binary attributes ("blobs") are stored in their own
files.

For example, the database for the example above would have a directory
structure that looks like this:

* db-root 
    * comments 
        * 2010-01-03-328
            * _attributes.json_
        * 2010-05-29-742
            * _attributes.json_
    * posts 
        * hotdog-eating-contest
            * _attributes.json_
            * _hotdogs.jpg_
            * _image_
            * _the-aftermath.jpg_
        * lessons-learned
            * _attributes.json_
            * _image_
        * running-with-scissors
            * _attributes.json_


Performance
-----------

GitModel supports memcached for query results. This is off by default, but can be configured like this:

```ruby
GitModel.memcache_servers(['server_1', 'server_2', ...])
GitModel.memcache_namespace('optional_namespace')
```

The namespace is optional, and usually not necessary because GitModel will prepend the last segment of GitModel.db_root anyway.

A Git SHA is also prepended to every key, so that outdated versions will not be retrieved from the cache. This is the SHA of the latest commit so unfortunately this is only useful when there are not frequent commits because every commit invalidates the cache. (This is obviously not ideal and I'm sure it can be improved upon.)

There is still a lot of work to be done to make it faster. First, some analysis is required, but some guesses about things that would help are:

* Use [Rugged](https://github.com/libgit2/rugged) instead of Grit
* Remove the transaction lock (see transaction.rb line 19)
* Ability to iterate over result set without eager loading of all instances


Contributing
------------

Do you have an improvement to make? Please submit a pull request on GitHub or a
patch, including a test written with RSpec.  To run all tests simply run
`autotest`.

The main author is [Paul Dowman](http://pauldowman.com/about) ([@pauldowman](http://twitter.com/pauldowman)).

Thanks to everyone who has contributed so far:

* [Alex Bartlow](https://github.com/alexbartlow)
* [Daniel Russo](https://github.com/drusso)


To do
-----

* Finish Query support
    * Update index (efficiently) when Persistable objects are saved
    * Add Rake task to generate index
    * Update README
* Add validations and other feature examples to sample code in README
* Finish some pending specs
* API documentation
* Rails integration
    * Generators
    * Rake tasks
* Performance
* Persistable.find/find_all/etc could be based on staged files so that queries reflect uncommitted changes
* Better query support
    * Associations
    * Use AREL?


Bugs
------------

* Grit 2.4.1 has [an issue with non-ASCII characters](https://github.com/mojombo/grit/commit/696761d8047ffd038dc2828e6a1998e3f7c3b419)

