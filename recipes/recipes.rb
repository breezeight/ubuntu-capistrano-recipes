namespace :mysql do
	desc "Create user granted to DROP/CREATE rails databases"
	task :create_rails_user do
    envs = ["development", "test", "production"]
    envs.each do |env|
      run "mysql mysql -u #{db_root_user} -p -e 'grant all on #{application}_#{env}.* to #{user}@localhost;' " do |channel, stream, data|
        channel.send_data "#{db_root_pw}\n"
        puts data
      end
    end
	end
end

namespace :dm_deploy do
  desc "Create all databases on the primary db server. Setup the database.yml file"
  task :create_databases, :roles => :db, :only => { :primary => true } do
    #1 config database.yml
    envs = ["development", "test", "production"]
    database_configuration = ""
    envs.each do |env|
    database_configuration += <<-EOF
#{env}:
    adapter: mysql
    socket: /var/run/mysqld/mysqld.sock
    username: #{user}
    password: 
    database: #{application}_#{env}
  
    EOF
    end
    put database_configuration, "#{current_path}/config/database.yml"
    
    #2 create mysql users
    mysql.create_rails_user
    
    #3 create databases
    rake = fetch(:rake, "rake")
    rails_env = fetch(:rails_env, "production")
    migrate_env = fetch(:migrate_env, "")
    migrate_target = fetch(:migrate_target, :latest)

    directory = case migrate_target.to_sym
      when :current then current_path
      when :latest  then current_release
      else raise ArgumentError, "unknown migration target #{migrate_target.inspect}"
      end
    run "cd #{directory}; #{rake} RAILS_ENV=#{rails_env} #{migrate_env} db:create:all"
    
  end
  
  desc "Set application directory user and permission"
  task :set_app_dir_access, :roles => :app do
    sudo "chown #{user}:#{user} -R #{deploy_to}"
  end
end

namespace :ubuntu804 do
    desc "Install Git"
    task :install_git do
        sudo "apt-get install git-core git-svn -y"
    end

    desc "Install Ruby"
    task :install_ruby do
        sudo "apt-get install ruby1.8 libopenssl-ruby1.8 ruby1.8-dev"
    end

    desc "Install Rails"
    task :install_rails do
        sudo "apt-get install libmysqlclient15-dev sqlite3 libsqlite3-ruby libsqlite3-dev"
        sudo "gem install sqlite3-ruby"
        sudo "gem install mysql"
        sudo "gem install rails-2.1.0"
        sudo "gem install rspec"
    end

    desc "Install Ruby"
    task :install_mysql do
        sudo "apt-get install mysql-server-5.0 mysql-client-5.0"
    end
    namespace :apache do
        desc "Install Apache"
        task :install do
            sudo "apt-get install apache2=2.2.8-1ubuntu0.3 apache2-mpm-prefork=2.2.8-1ubuntu0.3 apache2-utils=2.2.8-1ubuntu0.3 libexpat1=2.0.1-0ubuntu1 apache2-prefork-dev=2.2.8-1ubuntu0.3 libapr1-dev -y"
        end
        desc "Install Passenger"
        task :install_passenger do
            sudo "gem install passenger"
            print "TODO run passenger-install-apache2-module"
            input = ''
            run "sudo passenger-install-apache2-module" do |ch, stream, out|
              next if out.chomp == input.chomp || out.chomp == ''
              print out
              ch.send_data(input = $stdin.gets) if out =~ /enter/i
            end
        end

        desc "Configure Passenger"
        task :config_passenger do
            passenger_config =<<-EOF
LoadModule passenger_module /usr/lib/ruby/gems/1.8/gems/passenger-2.0.3/ext/apache2/mod_passenger.so
PassengerRoot /usr/lib/ruby/gems/1.8/gems/passenger-2.0.3
PassengerRuby /usr/bin/ruby1.8
EOF
            put passenger_config, "passenger"
            sudo "mv passenger /etc/apache2/conf.d/passenger"
        end

        desc "Configure VHost"
        task :config_vhost do
            vhost_config =<<-EOF
<VirtualHost *:80>
ServerName #{server_address}
DocumentRoot #{deploy_to}current/public
</VirtualHost>
EOF
            put vhost_config, "vhost_config"
            sudo "mv vhost_config /etc/apache2/sites-available/#{application}_#{user}"
            sudo "a2ensite #{application}_#{user}"
        end
    end
end
