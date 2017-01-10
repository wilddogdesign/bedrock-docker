set :stage, :production

# Simple Role Syntax
# ==================
#role :app, %w{deploy@example.com}
#role :web, %w{deploy@example.com}
#role :db,  %w{deploy@example.com}

# Extended Server Syntax
# ======================
server 'domain.com', user: 'user', roles: %w{web app db}
set :vhosts_path, '/Path/to/project/root'

# you can set custom ssh options
# it's possible to pass any option but you need to keep in mind that net/ssh understand limited list of options
# you can see them in [net/ssh documentation](http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start)
# set it globally
set :ssh_options, {
  keys: %w(~/.ssh/id_rsa),
  # forward_agent: false,
  # auth_methods: %w(password),
  port: '18765',
}

set :deploy_to, -> { "/Path/to/project/root" }
set :branch, :master

set :tmp_dir, '/Path/to/tmp'

set :default_env, { path: "path/to/bin:$PATH" }

SSHKit.config.command_map[:composer] = "/usr/local/php56/bin/php-cli ~/bin/composer.phar"
SSHKit.config.command_map[:node] = "~/bin/node"
SSHKit.config.command_map[:npm] = "~/bin/npm"
SSHKit.config.command_map[:gulp] = "~/bin/gulp"
SSHKit.config.command_map[:jspm] = "~/bin/jspm"
SSHKit.config.command_map[:yarn] = "~/bin/yarn"

fetch(:default_env).merge!(wp_env: :production)
