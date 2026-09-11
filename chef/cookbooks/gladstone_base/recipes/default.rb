# gladstone_base::default

# System Dependencies
%w(jq curl git bc zip cifs-utils python3 smbclient rclone apt-transport-https ca-certificates software-properties-common).each do |pkg|
  package pkg do
    action :install
  end
end

# Install Docker Engine
execute 'install_docker' do
  command 'curl -fsSL https://get.docker.com | sh'
  not_if 'which docker'
end

service 'docker' do
  action [:enable, :start]
end

# Create Gladstone OS User
execute 'create_gladstone_user' do
  command 'useradd -m -s /bin/bash gladstone && echo "gladstone:GladstoneTemp123!" | chpasswd'
  not_if 'id gladstone'
end

# Assign Groups
group 'sudo' do
  action :modify
  members 'gladstone'
  append true
end

group 'docker' do
  action :modify
  members 'gladstone'
  append true
end

# Ensure passwordless sudo during migration
file '/etc/sudoers.d/gladstone' do
  content "gladstone ALL=(ALL) NOPASSWD:ALL\n"
  mode '0440'
  owner 'root'
  group 'root'
  action :create
end

# Migrate Pi Data if exists
ruby_block 'migrate_pi_data' do
  block do
    if File.directory?('/home/pi')
      system("rsync -a --ignore-existing /home/pi/ /home/gladstone/")
      system("chown -R gladstone:gladstone /home/gladstone")
    end
  end
  action :run
end

# Deploy base scripts and bash profile
remote_directory '/home/gladstone/scripts' do
  source 'scripts'
  owner 'gladstone'
  group 'gladstone'
  mode '0755'
  files_mode '0755'
  action :create
end

cookbook_file '/home/gladstone/.bashrc' do
  source 'bashrc.webhost.template'
  owner 'gladstone'
  group 'gladstone'
  mode '0644'
  action :create
end

link '/home/gladstone/.bash_aliases' do
  to '/home/gladstone/scripts/aliases.sh'
  owner 'gladstone'
  group 'gladstone'
end

# Setup Terminal Buddy Shell Integration
directory '/home/gladstone/.config/terminalbuddy' do
  owner 'gladstone'
  group 'gladstone'
  mode '0755'
  recursive true
  action :create
end

remote_file '/home/gladstone/.config/terminalbuddy/terminalbuddy.sh' do
  source 'https://raw.githubusercontent.com/pmitchell-dev/TerminalBuddy/main/shell-integration/terminalbuddy.sh'
  owner 'gladstone'
  group 'gladstone'
  mode '0755'
  action :create
end
