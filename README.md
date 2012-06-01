Heroku CLI plugin for developing apps in organization accounts. Install with

    $ heroku plugins:install https://github.com/heroku/manager-cli.git
    manager-cli installed

See which orgs you are a member of:

    $ heroku manager:orgs
    You are a member of the following organizations (only IDs available):
    16
    29
    44
    45

Right now, only IDs are available. This will be fixed asap.

Transfer an app to an org:

    $ heroku manager:transfer --app hollow-warrior-3022 --org 47
    Transferring hollow-warrior-3022 to 47...done

Check the app after the transfer:

    $ heroku info --app hollow-warrior-3022
    === hollow-warrior-3022
    Addons:        SendGrid Test, Shared Database 5MB, Heroku Postgres Dev
    Collaborators: jesper@heroku.com
    Database Size: 240k
    Domain Name:   hollow-warrior-3022.herokuapp.com
    Git URL:       git@heroku.com:hollow-warrior-3022.git
    Owner:         org1cc537cf-373e-4a89-ab85-5b0ead6edfa4@heroku.com
    Repo Size:     10M
    Slug Size:     16M
    Stack:         cedar
    Web URL:       http://hollow-warrior-3022.herokuapp.com/

You'll see that you are now a collaborator on the app. While this output doesn't show it, your collaborator status is different. You have full access to the application and can perform actions such as scaling and provisioning addons.

