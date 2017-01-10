set :application, 'bedrock'
set :theme, 'bedrock-theme'
set :repo_url, 'git@github.com:meeshkah/bedrock-docker.git'
set :vhosts_path, 'path/to/vhosts/'

# Branch options
# Prompts for the branch name (defaults to current branch)
#ask :branch, -> { `git rev-parse --abbrev-ref HEAD`.chomp }

# Hardcodes branch to always be master
# This could be overridden in a stage config file
set :branch, :master

set :deploy_to, -> { "#{fetch(:vhosts_path)}#{fetch(:application)}" }

# Use :debug for more verbose output when troubleshooting
set :log_level, :info

# Git
set :scm, :git
set :git_strategy, Capistrano::Git::SubmoduleStrategy

# npm install
# set :npm_target_path, -> { release_path.join('templates') }
# set :npm_flags, '--silent --no-progress'
# set :npm_env_variables, {}

# composer install
set :composer_working_dir, -> { "#{fetch(:release_path)}/bedrock" }

# Apache users with .htaccess files:
# it needs to be added to linked_files so it persists across deploys:
set :linked_files, fetch(:linked_files, []).push(
  'bedrock/.env'
)
set :linked_dirs, fetch(:linked_dirs, []).push(
  'bedrock/web/app/uploads',
  'templates/node_modules',
  'templates/bower_components',
  'templates/jspm_packages',
)

namespace :npm do
  desc 'Copy npm files to tempates folder'
  task :build_assets do
    on roles(:app), in: :sequence do
      within "#{fetch(:release_path)}/templates" do
        execute :npm, "run", "setup"
        execute :npm, "run", "build"
      end
      execute :ln, "-s", "#{fetch(:release_path)}/templates/dist/assets/css", "#{fetch(:release_path)}/bedrock/web/app/themes/#{fetch(:theme)}/static/css"
      execute :ln, "-s", "#{fetch(:release_path)}/templates/dist/assets/js", "#{fetch(:release_path)}/bedrock/web/app/themes/#{fetch(:theme)}/static/js"
      execute :ln, "-s", "#{fetch(:release_path)}/templates/dist/assets/icons", "#{fetch(:release_path)}/bedrock/web/app/themes/#{fetch(:theme)}/static/icons"
    end
  end
end
after 'deploy:updated', 'npm:build_assets'

namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :service, :nginx, :reload
    end
  end
end

# The above restart task is not run by default
# Uncomment the following line to run it on deploys if needed
after 'deploy:publishing', 'deploy:restart'

namespace :deploy do
  desc 'Update WordPress template root paths to point to the new release'
  task :update_option_paths do
    on roles(:app) do
      within fetch(:release_path) do
        if test :wp, :core, 'is-installed'
          [:stylesheet_root, :template_root].each do |option|
            # Only change the value if it's an absolute path
            # i.e. The relative path "/themes" must remain unchanged
            # Also, the option might not be set, in which case we leave it like that
            value = capture :wp, :option, :get, option, raise_on_non_zero_exit: false
            if value != '' && value != '/themes'
              execute :wp, :option, :set, option, fetch(:release_path).join('web/wp/wp-content/themes')
            end
          end
        end
      end
    end
  end
end

# The above update_option_paths task is not run by default
# Note that you need to have WP-CLI installed on your server
# Uncomment the following line to run it on deploys if needed
# after 'deploy:publishing', 'deploy:update_option_paths'

namespace :deploy do
  desc 'Clear cache'
  task :clear_cache do
    on roles(:app) do
      if test "[[ -d #{shared_path}/bedrock/web/app/cache ]]"
        puts "Cleaning cache..."
        execute :rm, "-rf", "#{shared_path}/bedrock/web/app/cache/* #{shared_path}/bedrock/web/app/cache/.*"
      else
        puts "No cache"
      end
    end
  end
end

namespace :deploy do
  desc 'Notify team about deployment via slack'
  task :notify do
    on roles(:app) do |server|
      run_locally do
        user = capture("git config user.name")
        url = fetch(:stage) == :staging ? "https://#{fetch(:application)}.#{server.hostname}" : "http://#{server.hostname}"
        execute :curl, "-X", "POST", "--data-urlencode", "'payload={\"channel\": \"#deployments\", \"username\": \"deploybot\", \"text\": \"#{user} has just deployed *#{fetch(:application)}* project to <#{url}|its #{fetch(:stage)} server>\", \"icon_emoji\": \":shipit:\"}'", "https://hooks.slack.com/services/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"
      end
    end
  end
end
after 'deploy:finishing', 'deploy:notify'
