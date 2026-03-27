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

Test Recovery: (Optional but Recommended) Run update on your secondary device (Laptop) to ensure the new script pulls down correctly and permissions are set.
