# gladstone_webhost::default
include_recipe 'gladstone_base::default'

# Sync Application Source Code from GitHub
%w(
  JobBoard
  HomeAsset
).each do |repo|
  git "/home/gladstone/#{repo.downcase}" do
    repository "https://github.com/pmitchell-dev/#{repo}.git"
    revision 'master'
    user 'gladstone'
    group 'gladstone'
    action :sync
  end
end

git "/home/gladstone/piccurator" do
  repository "https://github.com/pmitchell-dev/duplicate-image-detective.git"
  revision 'master'
  user 'gladstone'
  group 'gladstone'
  action :sync
end

# Install required packages for SMB/CIFS and NTFS
package %w(samba cifs-utils smbclient ntfs-3g) do
  action :install
end

directory '/mnt/backups' do
  owner 'pi'
  group 'pi'
  mode '0755'
  action :create
end

# Persistently mount the external drive via fstab
mount '/mnt/backups' do
  device 'F6BCCD88BCCD43B9'
  device_type :uuid
  fstype 'ntfs-3g'
  options 'defaults,nofail,uid=1000,gid=1000,dmask=000,fmask=000,windows_names,x-systemd.device-timeout=30s,x-systemd.after=local-fs.target'
  dump 0
  pass 0
  action [:mount, :enable]
end

# Prepare Application Data Directories
home_dirs = [
  "/home/gladstone/jobboard/data/backups",
  "/home/gladstone/jobboard/cache",
  "/home/gladstone/rustdesk/data",
  "/home/gladstone/gemini-api/data"
]

mnt_dirs = [
  "/mnt/backups/family_photos",
  "/mnt/backups/recyclebin"
]

home_dirs.each do |dir|
  directory dir do
    owner 'gladstone'
    group 'gladstone'
    mode '0755'
    recursive true
    action :create
  end
end

mnt_dirs.each do |dir|
  directory dir do
    owner 'pi'
    group 'pi'
    mode '0755'
    recursive true
    action :create
  end
end

# Cron job for Webhost daily backups
cron_d 'webhost_daily_backup' do
  command "/home/gladstone/scripts/backup.sh"
  minute '0'
  hour '0'
  user 'gladstone'
end

# Ensure the 5-strike watchdog script runs via systemd timer (replaces services_manager loop)
systemd_unit 'gladstone_watchdog.service' do
  content <<~EOU
    [Unit]
    Description=Gladstone Webhost Watchdog
    After=network.target

    [Service]
    Type=oneshot
    ExecStart=/home/gladstone/scripts/services_manager.sh
    User=gladstone
  EOU
  verify false
  action [:create]
end

systemd_unit 'gladstone_watchdog.timer' do
  content <<~EOU
    [Unit]
    Description=Run Gladstone Webhost Watchdog every 5 minutes

    [Timer]
    OnBootSec=5min
    OnUnitActiveSec=5min

    [Install]
    WantedBy=timers.target
  EOU
  verify false
  action [:create, :enable, :start]
end

# Setup RClone Config Directory and Environment Variables
directory '/home/gladstone/.config/rclone' do
  owner 'gladstone'
  group 'gladstone'
  mode '0755'
  recursive true
  action :create
end

file '/home/gladstone/.config/rclone/rclone_photos.env' do
  content <<~EOF
    # Gladstone RClone Family Photos Sync Configuration
    # Managed by Chef

    GDRIVE_REMOTE="gdrive:Family Pictures"
    LOCAL_SOURCE_DIR="/mnt/backups/family_photos"
  EOF
  owner 'gladstone'
  group 'gladstone'
  mode '0644'
  action :create
end

# Cron job for Google Drive Photos Sync (Daily at 02:00 AM)
cron_d 'gdrive_photos_sync' do
  command "/home/gladstone/scripts/rclone_gdrive_photos.sh"
  minute '0'
  hour '2'
  user 'gladstone'
end

# Cron job to prune Docker weekly (Sundays at 03:00 AM)
cron_d 'docker_prune' do
  command "docker system prune -af --volumes"
  minute '0'
  hour '3'
  weekday '0'
  user 'gladstone'
end

# ==========================================
# Production Vault Setup
# ==========================================

execute 'add_hashicorp_gpg' do
  command 'wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg'
  creates '/usr/share/keyrings/hashicorp-archive-keyring.gpg'
end

file '/etc/apt/sources.list.d/hashicorp.list' do
  content "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com jammy main\n"
  notifies :update, 'apt_update[update_hashicorp]', :immediately
end

apt_update 'update_hashicorp' do
  action :nothing
end

package 'vault' do
  action :install
end

directory '/opt/vault/data' do
  owner 'vault'
  group 'vault'
  mode '0750'
  recursive true
  action :create
end

directory '/etc/vault.d' do
  owner 'vault'
  group 'vault'
  mode '0750'
  action :create
end

file '/etc/vault.d/vault.hcl' do
  content <<~EOV
    storage "file" {
      path = "/opt/vault/data"
    }

    listener "tcp" {
      address     = "127.0.0.1:8200"
      tls_disable = 1
    }

    ui = true
    disable_mlock = true
  EOV
  owner 'vault'
  group 'vault'
  mode '0640'
  action :create
end

systemd_unit 'vault.service' do
  content <<~EOU
    [Unit]
    Description=HashiCorp Vault
    Documentation=https://www.vaultproject.io/docs/
    Requires=network-online.target
    After=network-online.target

    [Service]
    User=vault
    Group=vault
    ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault.hcl
    ExecReload=/bin/kill --signal HUP $MAINPID
    KillMode=process
    KillSignal=SIGINT
    Restart=on-failure
    RestartSec=5
    TimeoutStopSec=30
    LimitNOFILE=65536
    LimitMEMLOCK=infinity

    [Install]
    WantedBy=multi-user.target
  EOU
  action [:create, :enable, :start]
  verify false
end
