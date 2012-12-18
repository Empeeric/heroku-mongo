require 'heroku/command/base'
require 'rest_client'
require 'date'

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
    display "heroku manager:usage --org ORG_NAME [--sort FIELD] [--month MONTH]"
    display "heroku manager:events --org ORG_NAME"
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

  # manager:collaborators --org ORG_NAME
  #
  # list all users who have access to apps in an org
  #
  # -o, --org ORG_NAME     # Organization name (required)
  # -r, --role ROLE        # Only list collaborators in a particular role
  # -u, --user EMAIL       # Show role and apps for a single user
  # -s, --sort role|email  # Sort by email (username) or role. Default is role.
  #
  def collaborators
    org = options[:org]
#    begin
      resp = json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/collaborators"))
      if resp.size == 0
        print_and_flush("No users in organization #{org}\n")
        return
      end
      max_user_width = resp.map { |x| x["email"] }.max { |a,b| a.length <=> b.length }.length
      max_role_width = 12 # 'collaborator'
      app_list_width = resp.map { |x| x["apps"] }.flatten.max { |a,b| a.length <=> b.length }.length

      fmt = "%-#{max_user_width}s  %-12s  %-#{app_list_width}s\n"

      puts
      printf(fmt, "User", "Role", "App list")
      printf(fmt, '-'*max_user_width, '-'*max_role_width, '-'*app_list_width)
      if options[:role]
        filtered = resp.select { |x| x["role"] == options[:role] }
      elsif options[:user]
        filtered = resp.select { |x| x["email"] == options[:user] }
      else
        filtered = resp
      end

      sort_field = options[:sort] || 'role'

      filtered.sort { |a,b| a[sort_field] <=> b[sort_field] }.each { |x|

        # Experimented with a wrapped comma separated list of app names (could be multiple on one lint)
        # But looks like we might as well just have one app name per line if we want to stay within 80

        #app_list = x["apps"].join(", ").scan(/\S.{0,#{app_list_width}}\S(?=\s|$)|\S+/)

        if x["role"] == 'admin'
          printf(fmt, x["email"], x["role"], "[all apps]")
        else
          printf(fmt, x["email"], x["role"], x["apps"][0] || "")
          if x["apps"].size > 1
            for i in 1..x["apps"].length-1
              printf(fmt, ' '*max_user_width, ' '*max_role_width, x["apps"][i])
            end
          end
        end
      }

      # puts "Administrators:"
      # puts user_list.select{ |u| u["role"] == "admin"}.collect { |u|
      #     "    #{u["email"]}"
      # }
      # puts "\nMembers:"
      # puts user_list.select{ |u| u["role"] == "member"}.collect { |u|
      #   "    #{u["email"]}"
      # }
    # rescue => e
    #   if e.response
    #     errorText = json_decode(e.response.body)
    #     print_and_flush("An error occurred: #{errorText["error_message"]}\n")
    #   else
    #     print_and_flush("An error occurred: #{e.message}\n")
    #   end
    # end
  end

  def wrapped_list(words, len, indent)
    lines = []
    line = ''
    words.each { |w|
      if line.length+2+w.length+1 > len
        line += ','
        lines << line
        line = ' '*indent+w
      else
        line += ', '+w
      end
    }
    return lines
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
      puts json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/app",{:accept => :json})).collect { |a|
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
            print_and_flush "#{Time.at(r["timestamp"]/1000)} #{r["actor"]} #{r["action"]} #{r["app"]} #{json_encode(r["attributes"])}\n"
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
  #   shows current or previous month's usage for an org
  #
  # -o, --org ORG        # Org to list usage for
  # -s, --sort FIELD     # sort by FIELD, one of 'dyno' or 'addon'
  # -m, --month MONTH    # show usage for MONTH (yyyy-dd). Current is default.
  #
  def usage
    org = options[:org]

    if org == nil
      raise Heroku::Command::CommandFailed, "No organization specified. Use the -o --org option to specify an organization."
    end

    apps = {}
    json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/app")).each { |a|
      apps[a["id"]] = a["name"]
    }
    longest_name = apps.size > 0 ? apps.values.max { |a,b| a.length <=> b.length }.length : 11

    res = []
    total_dyno = 0
    total_addon = 0

    if options[:month]
      ts = DateTime.parse(options[:month]+'-01')
      te = (ts >> 1)
      t_start = Time.utc(ts.year, ts.month, ts.day, ts.hour, ts.min, ts.sec)
      t_end = Time.utc(te.year, te.month, te.day, te.hour, te.min, te.sec) - 1
      grain = 'monthly'
    else
      t_end = Time.now.utc
      t_start = Time.utc(t_end.year,t_end.month,1)
      grain = 'daily'
    end

    puts "Usage for period #{t_start} to #{t_end}"
    usage = json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/usage/#{grain}/#{t_end.to_i*1000}/1"))
    if usage.size == 0
      puts "No usage records found for this period in organization #{org}"
      return
    end

    usage.select { |x| x["time"] >= t_start.to_i*1000 }.group_by { |x| x["resource_id"] }.each { |k,v|
      d = v.select { |x| x["product_group"] == 'dyno' }.map { |x| x["quantity"] }.inject(:+) || 0
      a = v.select { |x| x["product_group"] == 'addon' }.map { |x| x["quantity"]*x["rate"] }.inject(:+) || 0
      res << [ apps[k] || 'app'+k, d, a]
      total_dyno += d
      total_addon += a

    }

    if options[:sort] == 'dyno'
      res.sort! { |a,b| a[1] <=> b[1] }
    elsif options[:sort] == 'addon'
      res.sort! { |a,b| a[2] <=> b[2] }
    end

    puts
    printf("%-#{longest_name}s  %8s  %7s\n", "App name", "Dyno hrs", "Addon $")
    printf("%-#{longest_name}s  %8s  %7s\n", '-'*longest_name, '-'*8, '-'*7)

    res.each { |r|
      printf("%-#{longest_name}s  %8d  %7d\n", r[0], r[1].round, (r[2]/100).round)
    }

    printf("%-#{longest_name}s  %8s  %7s\n", '-'*longest_name, '-'*8, '-'*7)
    printf("%-#{longest_name}s  %8d  %7d\n", "Total", total_dyno.round, (total_addon/100).round)
    printf("%-#{longest_name}s  %8s  %7s\n", '='*longest_name, '='*8, '='*7)

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
