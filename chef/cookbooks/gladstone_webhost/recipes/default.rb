# gladstone_webhost::default
include_recipe 'gladstone_base::default'

# Prepare Application Data Directories
app_dirs = [
  "/home/gladstone/jobboard/data/backups",
  "/home/gladstone/jobboard/cache",
  "/home/gladstone/rustdesk/data",
  "/home/gladstone/gemini-api"
]

app_dirs.each do |dir|
  directory dir do
    owner 'gladstone'
    group 'gladstone'
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

# Cron job for Google Drive Photos Sync (Daily at 02:00 AM)
cron_d 'gdrive_photos_sync' do
  command "/home/gladstone/scripts/rclone_gdrive_photos.sh"
  minute '0'
  hour '2'
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
