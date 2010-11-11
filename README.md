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


Status
------

_It is nowhere near production ready but I'm working on it. Please feel free to
contribute tests and/or code to help!_


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
* Transactions
* Metadata for all database changes (Git commit messages, date & time, etc.)
* In order to be easily human-editable, the database is simply files and
  directores stored in a Git repository.  GitModel uses the Git repo directly
  (rather than Git's checked-out "working copy") but you can do a "git
  checkout" to view and manipulate the database contents, and then "git commit"
* Test-driven development and excellent test coverage
* Clean and easy-to-use API


Installation
------------

It's available as a [RubyGem](https://rubygems.org/gems/gitmodel):

    > gem install gitmodel


Usage
-----

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


To Do
-----

* Querying
  * Use AREL?
* Finish some pending specs
* Associations
* API documentation
* Rails integration
  * rake tasks
  * generators
* Performance
  * Haven't optimized for performance yet. 


