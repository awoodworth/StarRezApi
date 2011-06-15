StarRezApi Plugin
==========

This is a Rails plugin for the StarRez Web Services REST API and Report API. The StarRezApi
plugin leverages Ruby's metaprogramming powers to dynamically generate classes on the fly using
a combination of module mix-ins and dynamic method assignments.

The usage is certainly specific in terms of what you are attempting to do and your mileage may vary
for certain. Please review the source files for StarRezApi and StarRezReports for more specific
details on usage. All attempts have been made to mirror ActiveRecords core functionality.

You will need to provide your web services URL in the config.yml file. You can provide a different
URL For each Rails environment.

Requirements
=======

The HTTParty and XML Simple gems are required for this plugin. Install them with:

    $ gem install httparty
    $ gem install xml-simple


Examples
=======

__Dynamic Classes__
To dynamically define the StarRez tables your application will use you must load them somehow. Rather
than creating a bunch of empty class files you can create a method that will create these classes on
the fly.

    $ app/controllers/application_controller.rb
    
    # Define a before_filter for loading StarRez classes
    def create_starrez_classes
      %w(Entry Room RoomSpace).each do |table|
	      unless Object.const_defined?(table)
		      eval "class #{table}; include StarRezApi; include HTTParty::Icebox; end"
	      end
      end
    end

    $ app/controllers/entry_controller.rb
    
    # Run our before filter
    before_filter :create_starrez_classes
    
    # Display an Entry
    def show
      e = Entry.find(params[:id])
    end


__Standard Model__
You can create a model definition file in the _app/models/_ folder that you can the use to expand and add
additional methods, such as explicitly defined relationships with other models. A model definition would
look something like this.

    $ app/models/entry.rb
    
    class Entry
      include StarRezApi
      
      module ClassMethods
        def full_name
          self.name_first + " " + self.name_last
        end
      end
      extend ClassMethods      
    end    

Don't forget, YMMV with this gem. It works for us but there could be a few things that need to change for your install.
I'd encourage you to fork this repo and hack away.

Copyright (c) 2011 Daniel Reedy, Southern Illinois University Carbondale, released under the MIT license
