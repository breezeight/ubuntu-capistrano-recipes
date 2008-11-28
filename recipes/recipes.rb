namespace :ubuntu804 do
    desc "Install Git"
    task :install_git do
        sudo "apt-get install git-core git-svn -y"
    end

    desc "Install Ruby"
    task :install_ruby do
        apt.install({:base => %w(ruby=4.1 rdoc=4.1 libopenssl-ruby=4.1 ruby1.8-dev)}, :stable)
    end

    desc "Install Rails"
    task :install_rails do
        apt.install( {:base => %w(libmysqlclient15-dev sqlite3 libsqlite3-ruby libsqlite3-dev)}, :stable )
        gem2.install 'sqlite3-ruby'
        gem2.install 'mysql'
        gem2.install 'rails', '2.1.0'
        gem2.install 'rspec'
    end

    desc "Install Ruby"
    task :install_mysql do
        apt.install( {:base => %w(mysql-server-5.0 mysql-client-5.0)}, :stable )
    end
    namespace :apache do
        desc "Install Apache"
        task :install do
            sudo "apt-get install apache2=2.2.8-1ubuntu0.3 apache2-mpm-prefork=2.2.8-1ubuntu0.3 apache2-utils=2.2.8-1ubuntu0.3 libexpat1=2.0.1-0ubuntu1 apache2-prefork-dev=2.2.8-1ubuntu0.3 libapr1-dev -y"
        end
        desc "Install Passenger"
        task :install_passenger do
            gem2.install 'passenger'
            print "TODO run passenger-install-apache2-module"
            #            input = ''
            #            run "sudo passenger-install-apache2-module" do |ch, stream, out|
            #                next if out.chomp == input.chomp || out.chomp == ''
            #                print out
            #                ch.send_data(input = $stdin.gets) if out =~ /enter/i
            #            end
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
DocumentRoot #{deploy_to}/current/public
</VirtualHost>
EOF
            put vhost_config, "vhost_config"
            sudo "mv vhost_config /etc/apache2/sites-available/#{application}"
            sudo "a2ensite #{application}"
        end
    end
end
