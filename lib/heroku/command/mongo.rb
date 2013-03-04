require 'heroku/command/base'
require 'rest_client'
require 'date'

# manage apps in organization accounts
#

require 'uri'
require 'json'

module URI
  class MONGODB < Generic
    DEFAULT_PORT = 27017
  end
  @@schemes['MONGODB'] = MONGODB
end

class Heroku::Command::Mongo < Heroku::Command::BaseWithApp

    def index
        validate_arguments!

        key = "MONGOLAB_URI"
        vars = api.get_config_vars(app).body
        uri = URI(vars[key])
        hash = {}
        uri.instance_variables.each {|var| hash[var.to_s.delete("@").to_sym] = uri.instance_variable_get(var) }
        cmd = "mongo -u %{user} -p %{password} %{host}:%{port}%{path}" % hash
        exec(cmd)
    end

    
    def dump
        validate_arguments!

        key = "MONGOLAB_URI"
        vars = api.get_config_vars(app).body
        uri = URI(vars[key])
        hash = {}
        uri.instance_variables.each {|var| hash[var.to_s.delete("@").to_sym] = uri.instance_variable_get(var) }
        hash[:db] = hash[:path][1..-1]
        cmd = "mongodump -u %{user} -p %{password} -d %{db} -h %{host}:%{port}" % hash
        exec(cmd)
    end

end
