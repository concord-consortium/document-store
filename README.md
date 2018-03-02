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

Run the command: `docker-compose up`

Document server should be available at:

http://localhost:3001

Other useful tips can be found at:

https://github.com/concord-consortium/rigse/blob/master/docs/docker.md

Acknowledgements
----------------

This application was generated with the [rails_apps_composer](https://github.com/RailsApps/rails_apps_composer) gem
provided by the [RailsApps Project](http://railsapps.github.io/).


License
-------

The Document Store app code is licensed under the MIT License.

All other dependencies are under their own respective licenses.
