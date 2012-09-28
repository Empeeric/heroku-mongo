require 'heroku/command/base'
require 'rest_client'

# manage apps in organization accounts
#
class Heroku::Command::Manager < Heroku::Command::BaseWithApp
  MANAGER_HOST = ENV['MANAGER_HOST'] || "manager-api.heroku.com"

  # transfer
  #
  # transfer an app to an organization account
  #
  def index
    display "Commands:"
    display "heroku manager:users --org ORG_NAME"
    display "heroku manager:apps --org ORG_NAME"
    display "heroku manager:transfer (--to|--from) ORG_NAME [--app APP_NAME]"
    display "heroku manager:add_user --org ORG_NAME --user USER_EMAIL --role ROLE"
    display "heroku manager:add_contributor_to_app --org ORG_NAME --user USER_EMAIL [--app APP_NAME]"
    display "Heroku Teams Migration Commands:"
    display "heroku manager:team_to_org --team TEAM_NAME --org ORG_NAME"
    display "heroku manager:org_to_team --org ORG_NAME --team TEAM_NAME"

  end

  # manager:transfer (--to|--from) ORG_NAME [--app APP_NAME]
  #
  # transfer an app to or from an organization account
  #
  # -t, --to ORG         # Transfer application from personal account to this org
  # -f, --from ORG       # Transfer application from this org to personal account
  #
  def transfer
    to = options[:to]
    from = options[:from]

    if to.nil? && from.nil?
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization to transfer to or from with --to <org name> or --from <org name>."
    end

    if to && from
      raise Heroku::Command::CommandFailed, "Ambiguous option. Please specify either a --to <org name> or a --from <org name>. Not both."
    end

    begin
      heroku.get("/apps/#{app}")
    rescue RestClient::ResourceNotFound => e
      raise Heroku::Command::CommandFailed, "You do not have access to the app '#{app}'."
    end

    begin
      if to
        print_and_flush("Transferring #{app} to #{to}... ")
        response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{to}/app", json_encode({ "app_name" => app }), :content_type => :json)
        if response.code == 201
          print_and_flush(" done\n")
        else
          print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}")
        end
      else
        print_and_flush("Transferring #{app} from #{from} to your personal account... ")
        response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{from}/app/#{app}/transfer-out", "")
        if response.code == 200
          print_and_flush(" done\n")
        else
          print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}")
        end
      end
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("failed\nAn error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("failed\nAn error occurred: #{e.message}\n")
      end
    end
  end

  # manager:team_to_org --team TEAM_NAME --org ORG_NAME
  #
  # transfer all apps from a team to an organization account
  #
  # -t, --team TEAM         # Transfer applications from this team
  # -o, --org ORG       # Transfer applications to this org
  #
  def team_to_org
    team = options[:team]
    org = options[:org]

    if team.nil?
      raise Heroku::Command::CommandFailed, "No team specified.\nSpecify which team to transfer from with --team <team name>.\n"
    end

    if org.nil?
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization to transfer to with --org <org name>.\n"
    end

    print_and_flush("Transferring apps from #{team} to #{org}... ")

    begin
      response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/migrate-from-team", json_encode({ "team" => team }), :content_type => :json)

      if response.code == 200
        print_and_flush(" done\n")
      else
        print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}\n")
      end
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("failed\nAn error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("failed\nAn error occurred: #{e.message}\n")
      end
    end
  end

  # manager:org_to_team --org ORG_NAME --team TEAM_NAME
  #
  # transfer all apps from an organization to a team
  #
  # -t, --team TEAM     # Transfer applications to this team
  # -o, --org ORG       # Transfer applications from this org
  #
  def org_to_team
    team = options[:team]
    org = options[:org]

    if team.nil?
      raise Heroku::Command::CommandFailed, "No team specified.\nSpecify which team to transfer to with --team <team name>.\n"
    end

    if org.nil?
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization to transfer from with --org <org name>.\n"
    end

    print_and_flush("Transferring apps from #{org} to #{team}... ")

    begin
      response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/migrate-to-team", json_encode({ "team" => team }), :content_type => :json)

      if response.code == 200
        print_and_flush(" done\n")
      else
        print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}\n")
      end
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("failed\nAn error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("failed\nAn error occurred: #{e.message}\n")
      end
    end

  end

  # manager:add_user --org ORG_NAME --user USER_EMAIL --role ROLE
  #
  # add a user to your organization
  #
  # -u, --user USER_EMAIL     # User to add
  # -r, --role ROLE     # Role the user will have (manager or contributor)
  # -o, --org ORG       # Add user to this org
  #
  def add_user
    user = options[:user]
    org = options[:org]
    role = options[:role]

    if user.nil?
      raise Heroku::Command::CommandFailed, "No user specified.\nSpecify which user to add with --user <user email>.\n"
    end

    if org.nil?
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization to add the user to with --org <org name>.\n"
    end

    if role != 'admin' && role != 'member'
      raise Heroku::Command::CommandFailed, "Invalid role.\nSpecify which role the user will have with --role <role>\nValid values are 'admin' and 'member'.\n"
    end

    print_and_flush("Adding #{user} to #{org}... ")

    begin
      response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/user", json_encode({ "email" => user, "role" => role }), :content_type => :json)

      if response.code == 201
        print_and_flush(" done\n")
      else
        print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}\n")
      end
    rescue => e
      if e.response && e.response.code == 302
        print_and_flush("failed\n#{user} already belongs to #{org}\n")
      elsif e.response
        errorText = json_decode(e.response.body)
        print_and_flush("failed\nAn error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("failed\nAn error occurred: #{e.message}\n")
      end
    end

  end


  # manager:add_contributor_to_app --org ORG_NAME --user USER_EMAIL [--app APP_NAME]
  #
  # add a user to your organization
  #
  # -u, --user USER_EMAIL     # User to add
  # -o, --org ORG       # org the app is in
  #
  def add_contributor_to_app
    user = options[:user]
    org = options[:org]

    if user.nil?
      raise Heroku::Command::CommandFailed, "No user specified.\nSpecify which user to add with --user <user email>.\n"
    end

    if org.nil?
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization the app is in with --org <org name>.\n"
    end

    if app.nil?
      raise Heroku::Command::CommandFailed, "No app specified.\n"
    end

    print_and_flush("Adding #{user} to #{app}... ")

    begin
      response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/app/#{app}/developer", json_encode({ "email" => user }), :content_type => :json)

      if response.code == 201
        print_and_flush(" done\n")
      else
        print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}\n")
      end
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("failed\nAn error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("failed\nAn error occurred: #{e.message}\n")
      end
    end

  end

  # manager:users --org ORG_NAME
  #
  # list users in the specified org
  #
  # -o, --org ORG       # List users for this org
  #
  def users
    org = options[:org]
    puts "The following users are members of #{org}:"
    begin
      user_list = json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/user"))
      puts "Administrators:"
      puts user_list.select{ |u| u["role"] == "admin"}.collect { |u|
          "    #{u["email"]}"
      }
      puts "\nMembers:"
      puts user_list.select{ |u| u["role"] == "member"}.collect { |u|
        "    #{u["email"]}"
      }
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("An error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("An error occurred: #{e.message}\n")
      end
    end
  end

  # manager:apps --org ORG_NAME
  #
  # list apps in the specified org
  #
  # -o, --org ORG       # List apps for this org
  #
  def apps
    org = options[:org]
    puts "The following apps are part of #{org}:"
    begin
      puts json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/app")).collect { |a|
        "    #{a["name"]}"
      }
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("An error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("An error occurred: #{e.message}\n")
      end
    end
  end

  # manager:orgs
  #
  # list organization accounts that you have access to
  #
  def orgs
    puts "You are a member of the following organizations:"
    begin
      puts json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/user/info"))["organizations"].collect { |o|
          "    #{o["organization_name"]}"
      }
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("An error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("An error occurred: #{e.message}\n")
      end
    end
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
