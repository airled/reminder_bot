require 'mina/deploy'
require 'mina/git'

set :application_name, 'reminder_bot'
set :domain, '88.99.226.18'
set :deploy_to, '/home/reminder/app'
set :repository, 'git@github.com:airled/reminder_bot.git'
set :branch, 'master'
set :user, 'reminder'
set :shared_dirs, fetch(:shared_dirs, []).push('config', 'deps', '_build')

task :environment do
end

task :setup do
  in_path(fetch(:shared_path)) do
    command %{mkdir -p _build}
    command %{mkdir -p deps}
    command %{mkdir -p config}
    command %{touch "config/config.exs"}
  end
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
        invoke :deps
        invoke :compile
        invoke :migrate
      end
    end
  end
end

desc "Gets dependencies"
task :deps => :environment do
  command %{echo '-----> Getting dependencies'}
  command %{mix local.hex --force}
  command %{mix local.rebar --force}
  command %{mix deps.get}
end

desc "Compile"
task :compile => :environment do
  command %{echo '-----> Compiling'}
  command %{MIX_ENV=prod mix compile}
end

desc "Migrates database"
task :migrate => :environment do
  command %{echo '-----> Migrating'}
  command %{MIX_ENV=prod mix ecto.migrate}
end


