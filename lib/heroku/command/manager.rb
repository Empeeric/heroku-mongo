require 'heroku/command/base'
require 'rest_client'
require 'json'

# deploy to an app
#
class Heroku::Command::Manager < Heroku::Command::BaseWithApp
  DEFAULT_HOST = "manager-api.heroku.com"

  # transfer
  #
  # transfer an app to an organization account
  #
  def index
    display "Usage: heroku manager:transfer --org ORG_NAME [--app APP_NAME]"
  end

  # manager:transfer
  #
  # transfer an app to an organization account
  #
  # -o, --org ORG         # name of org to transfer the application to
  #
  def transfer
    org = options[:org]
    host = DEFAULT_HOST

    if org == nil
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization to transfer to with --org <org name>"
    end

    begin
      heroku.get("/apps/#{app}")
    rescue RestClient::ResourceNotFound => e
      raise Heroku::Command::CommandFailed, "You do not have access to the app '#{app}'"
    end

    print_and_flush("Transferring #{app} to #{org}...")
    RestClient.post("https://:#{api_key}@#{host}/api/v1/organization/#{org}/app", { :app_name => app }.to_json, :content_type => :json)

    print_and_flush("done\n")
  end

  # manager:orgs
  #
  # list organization accounts that you have access to
  #
  def orgs
    host = DEFAULT_HOST
    puts "You are a member of the following organizations:"
    puts JSON.parse(RestClient.get("https://:#{api_key}@#{host}/api/v1/user-info"))["organizations"].collect { |o|
        "    #{o["organization_name"]}"
    }
  end

  protected
  def api_key
    Heroku::Auth.api_key
  end

  def print_and_flush(str)
    print str
    $stdout.flush
  end

end
