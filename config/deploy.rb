require 'mina/deploy'
require 'mina/git'

set :application_name, 'reminder_bot'
set :domain, '138.201.187.144'
set :deploy_to, '/home/reminder'
set :repository, 'git@github.com:airled/reminder_bot.git'
set :branch, 'master'
set :user, 'reminder'
set :shared_dirs, fetch(:shared_dirs, []).push('config')

task :environment do
end

task :setup do
  command %{mkdir -p "/home/reminder/shared/config"}
  command %{touch "/home/reminder/shared/config/config.exs"}
end

desc "Deploys the current version to the server."
task :deploy do
  # invoke :'git:ensure_pushed'
  deploy do
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'deploy:cleanup'
    on :launch do
      in_path(fetch(:current_path)) do
        command %{mkdir -p tmp/}
        command %{touch tmp/restart.txt}
      end
    end
  end
end

desc "Gets dependencies"
task :deps => :environment do
  command "echo '-----> Getting dependencies...' && cd ~/current && mix deps.get"
end

desc "Compile"
task :compile => :environment do
  command "echo '-----> Compiling...' && cd ~/current && MIX_ENV=prod mix compile"
end

desc "Migrates database"
task :migrate => :environment do
  command "echo '-----> Migrating...' && cd ~/current && MIX_ENV=prod mix ecto.migrate"
end


