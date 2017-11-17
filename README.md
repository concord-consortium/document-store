Document Store
=========

Getting Started
---------------

Document Store is a basic rails app for storing documents. It handles authentication through OAuth2 with a Concord Consortium
portal, and/or it's own internal user table.

It relies on PostgreSQL and its JSON column type.

0. Install dependencies: `bundle install`
0. Create your database.yml

        production:
          adapter:  postgresql
          host:     localhost
          encoding: unicode
          database: documentstore_production
          pool:     5
          username: user
          password: pw

0. Create the db: `rake db:create`
0. Run migrations: `rake db:migrate`
0. Set up a default user: `rake db:seed`
0. Start the server: `rails s`

Setting up a Portal authentication provider
-------------------------------------------

0. Set up a new Client in the providing portal:

        Client.create!(name: '<some unique name>', app_id: '<some unique id>', app_secret: '<some unique secret>')

0. In the document store:

        Settings['auth.<some_unqigue_name>'] = {
          display_name: '<some nicely formatted name>',
          url: <url to the portal>,
          client_id: <app_id from above>,
          client_secret: <app_secret from above>
        }

0. Restart the document server

Docker
------

A first pass at Docker support for this app is available.
This is not currently working to run the app itself.
But it is working well enough to update gems for example.
`docker-compose run web bundle install`

In theory you should be able to run the app by:
copying the config/database.yml.docker to config/database.yml
Then create the database `docker-compose run web bundle exec rake db:create`
Finally start the server with running `docker-compose up`

However currently it seems to start, but it is not accessible when going to
http://localhost:3000

Acknowledgements
----------------

This application was generated with the [rails_apps_composer](https://github.com/RailsApps/rails_apps_composer) gem
provided by the [RailsApps Project](http://railsapps.github.io/).


License
-------

The Document Store app code is licensed under the MIT License.

All other dependencies are under their own respective licenses.
