require "heroku/command/base"
require "uri"

module URI
    class MONGODB < Generic
        DEFAULT_PORT = 27017
    end
    @@schemes['MONGODB'] = MONGODB
end


# manage some MongoDBaaS
#
class Heroku::Command::Mongo < Heroku::Command::Base

    # mongo
    #
    # manage some MongoDBaaS
    #
    # -d, --dbname  # name of the local DB
    #
    def index
      validate_arguments!

      cmd = "mongo -u %{user} -p %{password} %{host}:%{port}%{path}" % hash
      exec(cmd)
    end


    def console
        validate_arguments!

        key = "MONGOLAB_URI"
        vars = api.get_config_vars(app).body
        uri = URI(vars[key])
        hash = {}
        uri.instance_variables.each {|var| hash[var.to_s.delete("@").to_sym] = uri.instance_variable_get(var) }
        cmd = "mongo -u %{user} -p %{password} %{host}:%{port}%{path}" % hash
        exec(cmd)
    end


    # mongo:dump
    #
    # dump the remote db and load it to local DBNAME
    #
    # -d, --dbname DBNAME  # load it to local DBNAME
    def dump
        dbname = shift_argument
        validate_arguments!

        key = "MONGOLAB_URI"
        vars = api.get_config_vars(app).body
        uri = URI(vars[key])
        hash = {}
        uri.instance_variables.each {|var| hash[var.to_s.delete("@").to_sym] = uri.instance_variable_get(var) }
        hash[:db] = hash[:path][1..-1]
        cmd = "mongodump -u %{user} -p %{password} -d %{db} -h %{host}:%{port}" % hash
        exec(cmd)
        if dbname
            cmd1 = "mongorestore --drop -d %{dbname} dump/%{db}" % hash
            exec(cmd1)
        end
    end

    
    # mongo:load
    #
    # load it to local DBNAME
    #
    # -d, --dbname DBNAME  # load it to local DBNAME
    def load
        validate_arguments!

        key = "MONGOLAB_URI"
        vars = api.get_config_vars(app).body
        uri = URI(vars[key])
        hash = {}
        uri.instance_variables.each {|var| hash[var.to_s.delete("@").to_sym] = uri.instance_variable_get(var) }
        hash[:db] = hash[:path][1..-1]
        hash[:dbname] = options[:dbname]
        cmd1 = "mongorestore --drop -d %{dbname} dump/%{db}" % hash
        exec(cmd1)
    end

    
    
    def restore
        @app = shift_argument || options[:app] || options[:confirm]
        validate_arguments!
        unless @app
          error("Usage: heroku mongo:restore --app APP\nMust specify APP to restore to.")
        end

        api.get_app(@app) # fail fast if no access or doesn't exist

        message = "WARNING: Potentially Destructive Action\nThis command will destroy data for #{@app} ."
        if confirm_command(@app, message)
            action("Restoring #{@app}") do
                key = "MONGOLAB_URI"
                vars = api.get_config_vars(app).body
                uri = URI(vars[key])
                hash = {}
                uri.instance_variables.each {|var| hash[var.to_s.delete("@").to_sym] = uri.instance_variable_get(var) }
                hash[:db] = hash[:path][1..-1]
                cmd = "mongorestore --drop -u %{user} -p %{password} -d %{db} -h %{host}:%{port} dump/%{db}" % hash
                exec(cmd)
            end
        end
    end

end