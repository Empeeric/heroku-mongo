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

      if e.response && e.response.code == 302
         print_and_flush("App #{app} already in organization #{to}\n")
      elsif e.response
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

    print_and_flush("Adding team members to #{org}: \n")
    team_members = json_decode(heroku.get("/v3/teams/#{team}/members"))
    team_members.each { |member|

      print_and_flush("Adding member #{member["user_email"]}... ")
      begin
        response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/user", json_encode({ "email" => member["user_email"], "role" => "member" }), :content_type => :json)

        if response.code == 201
          print_and_flush("done\n")
        else
          print_and_flush("failed - An error occurred: #{response.code}\n#{response}\n")
        end
      rescue => e
        if e.response && e.response.code == 302
          print_and_flush("#{member["user_email"]} already belongs to #{org}\n")
        elsif e.response
          errorText = json_decode(e.response.body)
          print_and_flush("failed - An error occurred: #{errorText["error_message"]}\n")
        else
          print_and_flush("failed - An error occurred: #{e.message}\n")
        end
      end


    }

    print_and_flush("Transferring apps from #{team} to #{org}... ")

    begin
      response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/migrate-from-team", json_encode({ "team" => team }), :content_type => :json)

      if response.code == 200
        print_and_flush("done\n")
      else
        print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}\n")
      end
    rescue => e
      if e.response
        puts e.response
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

  # manager:events --org ORG_NAME [--app APP_NAME]
  #
  # list audit events for an org
  #
  # -o, --org ORG        # Org to list events for
  #
  def events
    org = options[:org]
    app_name = options[:app]

    if org == nil
      raise Heroku::Command::CommandFailed, "No organization specified. Use the -o --org option to specify an organization."
    end
    begin
      if app_name == nil
        path = "/v1/organization/#{org}/events"
      else
        path = "/v1/organization/#{org}/app/#{app_name}/events" 
      end
      
        go = true

        while(go) 
          resp = json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}#{path}"))

          resp["events"].each { |r|
            print_and_flush "#{Time.at(r["time_in_millis_since_epoch"]/1000)} #{r["actor"]} #{r["action"]} #{r["app"]} #{json_encode(r["attributes"])}\n"
          }

          go = resp.has_key?("older") 
          if go && confirm("Fetch More Results? (y/n)")
             path = resp["older"]   
          else 
              go = false 
          end
      end 

    rescue => e
      print_and_flush("An error occurred: #{e}\n")
    end

  end

  # usage --org ORG
  #
  #   shows last month's usage for an org
  #
  # -o, --org ORG        # Org to list events for
  # -s, --sort FIELD     # sort by FIELD, one of 'dyno' or 'addon'
  #
  def usage
    org = options[:org]

    apps = {}
    json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/app")).each { |a|
      apps[a["id"]] = a
    }
    longest_name = apps.values.map { |x| x["name"] }.max { |a,b| a.length <=> b.length }.length

    res = []
    total_dyno = 0
    total_addon = 0
    usage = json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/usage/monthly/#{Time.now.to_i*1000}/1"))
    latest_month = usage.map { |x| x["time"] }.max

    usage.select { |x| x["time"] == latest_month }.group_by { |x| x["resource_id"] }.each { |k,v|
      d = v.select { |x| x["product_group"] == 'dyno' }.map { |x| x["quantity"] }.inject(:+) || 0
      a = v.select { |x| x["product_group"] == 'addon' }.map { |x| x["quantity"]*x["rate"] }.inject(:+) || 0
      res << [ (apps[k] || {"name" => "deleted"})["name"], d, a]
      total_dyno += d
      total_addon += a

    }

    if options[:sort] == 'dyno'
      res.sort! { |a,b| a[1] <=> b[1] }
    elsif options[:sort] == 'addon'
      res.sort! { |a,b| a[2] <=> b[2] }
    end

    printf("%-#{longest_name}s       %4d-%02d\n", "", Time.at(latest_month/1000).year, Time.at(latest_month/1000).utc.month)
    printf("%-#{longest_name}s  %8s--%7s\n", "", '-'*8, '-'*7)
    printf("%-#{longest_name}s  %8s  %7s\n", "App name", "Dyno hrs", "Addon $")
    printf("%-#{longest_name}s  %8s  %7s\n", '-'*longest_name, '-'*8, '-'*7)

    res.each { |r|
      printf("%-#{longest_name}s  %8d  %7d\n", r[0], r[1].round, (r[2]/100).round)
    }

    printf("%-#{longest_name}s  %8s  %7s\n", '-'*longest_name, '-'*8, '-'*7)
    printf("%-#{longest_name}s  %8d  %7d\n", "Total", total_dyno.round, (total_addon/100).round)
    printf("%-#{longest_name}s  %8s  %7s\n", '='*longest_name, '='*8, '='*7)

    #res.sort! { |a,b| a[3] <=> b[3] }
    #res << [ "-----", "-----", "-----", "-----"]
    #res << [ "total", "", total_dyno.round.to_s, total_addon.round.to_s]


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
