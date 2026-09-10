# gladstone_webhost::default
include_recipe 'gladstone_base::default'

# Prepare Application Data Directories
app_dirs = [
  "/home/gladstone/jobboard/data/backups",
  "/home/gladstone/jobboard/cache",
  "/home/gladstone/relayit/data/pgdata",
  "/home/gladstone/relayit/data/caddy_data",
  "/home/gladstone/relayit/data/caddy_config",
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
