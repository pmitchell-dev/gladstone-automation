# gladstone_hub::default
include_recipe 'gladstone_base::default'

# Install speedtest-cli
package 'speedtest-cli' do
  action :install
end

# Cron job for printer scrape
cron_d 'printer_scrape' do
  command "/home/gladstone/scripts/printer_health.sh"
  minute '0'
  hour '*/4'
  user 'gladstone'
end

# Cron job for network audit
cron_d 'network_audit' do
  command "/home/gladstone/scripts/net_speed.sh"
  minute '0'
  hour '*/6'
  user 'gladstone'
end

# Cron job for daily backups targeting NTFY Hub Target
cron_d 'hub_daily_backup' do
  command "/home/gladstone/scripts/backup.sh"
  minute '0'
  hour '0'
  user 'gladstone'
end

# Ensure ntfy listener is running via systemd
systemd_unit 'ntfy_listener.service' do
  content <<~EOU
    [Unit]
    Description=ntfy Listener for Gladstone Hub
    After=network.target

    [Service]
    ExecStart=/home/gladstone/scripts/ntfy_listener.sh
    Restart=always
    User=gladstone

    [Install]
    WantedBy=multi-user.target
  EOU
  action [:create, :enable, :start]
end
