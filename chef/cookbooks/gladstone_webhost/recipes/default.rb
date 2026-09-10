# gladstone_webhost::default
include_recipe 'gladstone_base::default'

# Prepare Application Data Directories
app_dirs = [
  "#{ENV['HOME']}/jobboard/data/backups",
  "#{ENV['HOME']}/jobboard/cache",
  "#{ENV['HOME']}/relayit/data/pgdata",
  "#{ENV['HOME']}/relayit/data/caddy_data",
  "#{ENV['HOME']}/relayit/data/caddy_config",
  "#{ENV['HOME']}/rustdesk/data",
  "#{ENV['HOME']}/gemini-api"
]

app_dirs.each do |dir|
  directory dir do
    owner ENV['USER'] || 'pi'
    group ENV['USER'] || 'pi'
    mode '0755'
    recursive true
    action :create
  end
end

# Cron job for Webhost daily backups
cron_d 'webhost_daily_backup' do
  command "#{ENV['HOME']}/scripts/pi_backup.sh"
  minute '0'
  hour '0'
  user ENV['USER'] || 'pi'
end

# Ensure the 5-strike watchdog script runs via systemd timer (replaces pi_services_manager loop)
systemd_unit 'gladstone_watchdog.service' do
  content <<~EOU
    [Unit]
    Description=Gladstone Webhost Watchdog
    After=network.target

    [Service]
    Type=oneshot
    ExecStart=#{ENV['HOME']}/scripts/pi_services_manager.sh
    User=#{ENV['USER'] || 'pi'}
  EOU
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
  action [:create, :enable, :start]
end

# Cron job for Google Drive Photos Sync (Daily at 02:00 AM)
cron_d 'gdrive_photos_sync' do
  command "#{ENV['HOME']}/scripts/rclone_gdrive_photos.sh"
  minute '0'
  hour '2'
  user ENV['USER'] || 'pi'
end
