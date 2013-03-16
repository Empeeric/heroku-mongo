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
    # -u, --dburl DBURL    # load it to local DBNAME
    def index
        console
    end

    

    # -u, --dburl DBURL    # load it to local DBNAME
    def console
        validate_arguments!
        hash = get_parsed_db_params
        cmd = "mongo -u %{user} -p %{password} %{host}:%{port}%{path}" % hash
        exec(cmd)
    end



    # mongo:dump
    #
    # dump the remote db and load it to local DBNAME
    #
    # -d, --dbname DBNAME  # load it to local DBNAME
    # -u, --dburl DBURL    # load it to local DBNAME
    def dump
        validate_arguments!
        hash = get_parsed_db_params
        cmd = "mongodump -u %{user} -p %{password} -d %{db} -h %{host}:%{port}" % hash
        exec(cmd)
        if options[:dbname]
            load
        end
    end

    

    # mongo:load
    #
    # load it to local DBNAME
    #
    # -d, --dbname DBNAME  # load it to local DBNAME
    # -u, --dburl DBURL    # load it to local DBNAME
    def load
        validate_arguments!
        hash = get_parsed_db_params
        cmd1 = "mongorestore --drop -d %{dbname} %{dumppath}" % hash
        exec(cmd1)
    end

    
    
    # mongo:load
    #
    # load it to local DBNAME
    #
    # -d, --dbname DBNAME  # load it to local DBNAME
    # -u, --dburl DBURL    # load it to local DBNAME
    def restore
        validate_arguments!

        api.get_app(app) # fail fast if no access or doesn't exist

        message = "WARNING: Potentially Destructive Action\nThis command will destroy data for #{@app} ."
        if confirm_command(app, message)
            action("Restoring #{app}") do
                hash = get_parsed_db_params
                print "\nBacking up current production data to %{bkpath}\n" % hash
                spawn "mongodump -u %{user} -p %{password} -d %{db} -h %{host}:%{port} -o %{bkpath}" % hash
                Process.waitall
                print "\nRestoring\n" % hash
                exec "mongorestore --drop -u %{user} -p %{password} -d %{db} -h %{host}:%{port} %{dumppath}" % hash
            end
        end
    end

    

    def get_parsed_db_params
        vars = api.get_config_vars(app).body
        raw_uri = options[:dburl] || vars["MONGOLAB_URI"] || vars["MONGOHQ_URL"]
        display(raw_uri)
        uri = URI(raw_uri)
        hash = {}
        uri.instance_variables.each {|var| hash[var.to_s.delete("@").to_sym] = uri.instance_variable_get(var) }
        hash[:db] = hash[:path][1..-1]
        hash[:dbname] = options[:dbname] || app
        hash[:dumppath] = "dump/%{db}" % hash
        hash[:timestamp] = String(Time::now)[0...19].tr(' :', '-')
        hash[:bkpath] = "dump/#{@app}-%{timestamp}" % hash
        hash
    end

end