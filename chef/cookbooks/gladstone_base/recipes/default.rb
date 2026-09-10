# gladstone_base::default

# System Dependencies
%w(jq curl git bc zip cifs-utils python3 smbclient rclone apt-transport-https ca-certificates software-properties-common).each do |pkg|
  package pkg do
    action :install
  end
end

# Install Docker Engine (simplified approach using docker convenience script for bare metal)
execute 'install_docker' do
  command 'curl -fsSL https://get.docker.com | sh'
  not_if 'command -v docker'
end

group 'docker' do
  action :modify
  members ENV['USER'] || 'pi'
  append true
end

service 'docker' do
  action [:enable, :start]
end

# Deploy base scripts and aliases
cookbook_file "#{ENV['HOME']}/.bash_aliases" do
  source 'bashrc.webhost.template'
  owner ENV['USER'] || 'pi'
  group ENV['USER'] || 'pi'
  mode '0644'
  action :create
end
