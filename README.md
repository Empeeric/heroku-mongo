##Dependecies:
Get the MongoDB binaries into your path

##Installation
Heroku CLI plugin for interacting with heroku-mongo

    $ heroku plugins:install https://github.com/Empeeric/heroku-mongo.git
    heroku-mongo installed

##Usage
Open console:

    $ heroku mongo

Dump remote DB to local directory:

    $ heroku mongo:dump

Load a dumbed directory (with remote name) to a local DB with app name:

    $ heroku mongo:load

Save a local DB to a dump directory with app name:

    $ heroku mongo:save


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/Empeeric/heroku-mongo/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

