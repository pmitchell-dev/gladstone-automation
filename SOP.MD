🛠️ Gladstone Development SOP (Standard Operating Procedure)
Version: 1.0.0

Purpose: Ensuring 100% integration of new scripts, aliases, and tasks.

Follow these steps every time you modify the Gladstone environment to prevent "orphan scripts" or broken dashboards.

1. Adding a New Script (.sh)
When you create a new functional script (e.g., check_garage.sh):

Placement: Save it in ~/scripts/.

Permissions: Run bash ~/scripts/install.sh immediately.

Why: This ensures the new file gets the correct +x (executable) bit.

Documentation: Add the script name and a 1-sentence purpose to the 📂 Core File Registry table in SYSTEM_CONTEXT.md.

Dashboard Integration: * Open pi-dashboard.sh.

Add a new echo line in Section 2 to show if the script is active or when it last ran.

2. Adding a New Alias
When you want a new shorthand command (e.g., log to view ntfy.log):

Define: Open ~/scripts/aliases.sh.

Add: Append the alias: alias log='tail -f ~/ntfy.log'.

Sync to Dashboard: Open pi-dashboard.sh and scroll to Section 4 (Quick Reference). Add the command name to the LOCAL (Bash) list so you don't forget it exists.

Apply: Run the refresh command (or source ~/.bashrc) to activate it in your current session.

3. Adding a New Crontab Entry
When you want to schedule a task (e.g., every morning at 9 AM):

DO NOT USE crontab -e manually. 2.  Update the Source: Open ~/scripts/pi_rebuild.sh.

Modify Section 4: Add your new logic to the bracketed list.

Example: echo "0 9 * * * /home/pi/scripts/my_new_task.sh"

Update the Registry: If the task is a background service that must stay alive, add it to services.registry.

Deploy: Run the rebuild command. This wipes the old cron and applies the new "Master" version from your script.

4. The "Post-Change" Checklist
Once you have made any of the above changes, you MUST run this sequence to lock them in:

Verify Locally: Run db (Dashboard) to see if your new info appears.

Update Metadata: Update the Version and Last Updated date at the top of README.md and SYSTEM_CONTEXT.md.

Cloud Sync: Run sync.

Why: This pushes your changes to GitHub so that if the Pi dies 5 minutes from now, your new script isn't lost.

5. Updating the Dozzle Log Viewer (or any Docker Compose Stack)
When you modify a compose file (e.g., dozzle-agent-compose.yml, jobboard-compose.yml):

  DO NOT run docker compose up directly from /home/pi/dozzle or similar.
  These directories contain COPIES managed by install.sh.
  Running docker compose there without re-running install.sh uses stale config.

  Correct update flow (Pi5 / ntfy hub):
    cd /home/pi/scripts && git pull && ./install.sh

  Correct update flow (Webhost / laptop):
    cd /home/pi/scripts && git pull && ./install.sh --webhost

  Why: install.sh copies the compose files from ~/scripts/ into their
  deployment directories (/home/pi/dozzle/, /home/pi/jobboard/, etc.)
  before restarting the containers. Skipping this step means the container
  restarts with the old configuration, making any fix appear to not work.

6. Log Viewer Quick Reference
  URL:     http://192.168.50.217:8888
  Pi5 hub: Dozzle agent on port 7007 (auto-connected)
  Scripts: /home/pi/scripts/logs/ → streamed via gladstone-scripts-log container
  NVR:     ANNKE Alarm Host → 192.168.50.217:514 (UDP) → nvr-syslog container

7. Google Drive RClone Media Sync Setup
  Script:  ~/scripts/rclone_gdrive_photos.sh
  Config:  ~/.config/rclone/rclone.conf (Run 'rclone config' or copy config file)
  Remote:  gdrive:Family Photos -> Target: /mnt/network_backups/Family Photos
  Notice:  rebuild & update auto-generate ~/.config/rclone/rclone.conf.example if unconfigured.
  Aliases: sync-photos | photos-sync
