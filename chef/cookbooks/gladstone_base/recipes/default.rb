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
  not_if 'command -v docker'
end

service 'docker' do
  action [:enable, :start]
end

# Create Gladstone OS User
execute 'create_gladstone_user' do
  command 'useradd -m -s /bin/bash gladstone && echo "gladstone:root" | chpasswd'
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

# Deploy base scripts and aliases
cookbook_file "/home/gladstone/.bash_aliases" do
  source 'bashrc.webhost.template'
  owner 'gladstone'
  group 'gladstone'
  mode '0644'
  action :create
end
