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
        cmd = "mongo -u %{user} -p %{password} %{host}:%{port}%{path}\n" % hash
        print cmd
        exec(cmd)
    end



    # mongo:dump
    #
    # dump the remote db and load it to local DBNAME
    #
    # -d, --dbname DBNAME       # load it to local DBNAME
    # -u, --dburl DBURL         # load it to DBURL
    # -o, --outpath DUMPPATH    # store files in DUMPPATH
    def dump
        validate_arguments!
        hash = get_parsed_db_params
        cmd = "mongodump -u %{user} -p %{password} -d %{db} -h %{host}:%{port} -o %{dumppath}\n"  % hash
        print cmd
        exec(cmd)
        if options[:dbname]
            load
        end
    end
    alias_command "dump", "mongo:dump"

    

    # mongo:load
    #
    # load it to local DBNAME
    #
    # -d, --dbname DBNAME       # load it to local DBNAME
    # -u, --dburl DBURL         # load it to DBURL
    # -o, --outpath DUMPPATH    # stored files are in DUMPPATH
    def load
        validate_arguments!
        hash = get_parsed_db_params
        cmd = "mongorestore --drop -d %{dbname} %{dumppath}\n" % hash
        print cmd
        exec(cmd)
    end
    alias_command "load", "mongo:load"

    
    
    # mongo:load
    #
    # load it to local DBNAME
    #
    # -p, --respath PATH       # path to dump to restore
    # -u, --dburl DBURL        # load it to local DBNAME
    # -o, --outpath BKPATH     # store files in BKPATH
    def restore
        validate_arguments!

        api.get_app(app) # fail fast if no access or doesn't exist

        hash = get_parsed_db_params
        message1 = "WARNING: Potentially Destructive Action\nThis command will destroy data for #{@app}.\n"
        message2 = "\nBacking up current production data to %{bkpath}\n" % hash
        cmd1 = "mongodump -u %{user} -p %{password} -d %{db} -h %{host}:%{port} -o %{bkpath}\n" % hash
        cmd2 = "mongorestore --drop -u %{user} -p %{password} -d %{db} -h %{host}:%{port} %{restorepath}\n" % hash
        print message1
        if confirm_command(app, message)
            action("Restoring #{app}") do
                print message2
                print cmd1
                spawn cmd1
                Process.waitall
                print "\nRestoring\n" % hash
                print cmd2
                exec cmd2
            end
        end
    end
    alias_command "restore", "mongo:restore"

    

    def get_parsed_db_params
        vars = api.get_config_vars(app).body
        raw_uri = options[:dburl] || vars["MONGOLAB_URI"] || vars["MONGOHQ_URL"]
        display(raw_uri)
        uri = URI(raw_uri)
        hash = {}
        uri.instance_variables.each {|var| hash[var.to_s.delete("@").to_sym] = uri.instance_variable_get(var) }
        hash[:db] = hash[:path][1..-1]
        hash[:dbname] = options[:dbname] || app
        hash[:dumppath] = options[:dumppath] || "dump/%{db}" % hash
        hash[:restorepath] = options[:respath] || options[:dumppath]
        hash[:timestamp] = String(Time::now)[0...19].tr(' :', '-')
        hash[:bkpath] = options[:bkpath] || "${dumppath}/#{@app}-%{timestamp}" % hash
        hash
    end

    
end