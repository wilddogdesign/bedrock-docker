set :stage, :staging

# Simple Role Syntax
# ==================
#role :app, %w{deploy@example.com}
#role :web, %w{deploy@example.com}
#role :db,  %w{deploy@example.com}

# Extended Server Syntax
# ======================
server 'domain.com', user: 'user', roles: %w{web app db}
set :vhosts_path, '/Path/to/wherever'

# you can set custom ssh options
# it's possible to pass any option but you need to keep in mind that net/ssh understand limited list of options
# you can see them in [net/ssh documentation](http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start)
# set it globally
set :ssh_options, {
  keys: %w(~/.ssh/id_rsa),
  # forward_agent: false,
  # auth_methods: %w(password)
}

set :branch, :staging

set :default_env, { path: "/path/to/bin:$PATH" }

set :nvm_node, 'v7.5.0'
set :nvm_map_bins, %w{node npm jspm bower}

fetch(:default_env).merge!(wp_env: :staging)
