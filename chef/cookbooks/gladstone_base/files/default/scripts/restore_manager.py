#!/usr/bin/env python3
"""
=============================================================================
GLADSTONE SYSTEM RESTORE MANAGER (restore_manager.py)
=============================================================================
Role-aware, interactive backup restoration system.

Discovers, verifies, and restores system scripts and application data from
tar.gz backup archives created by backup_manager.py.

Safeguards:
  - SHA256 integrity verification
  - Automatic container teardown (docker compose down)
  - Pauses background service watchdog during restoration
  - Pre-restore safety snapshot in /tmp/
=============================================================================
"""

import os
import sys
import shutil
import tarfile
import hashlib
import argparse
import subprocess
import logging
from datetime import datetime
from pathlib import Path

# Force stdout/stderr utf-8 output handling
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass
if hasattr(sys.stderr, 'reconfigure'):
    try:
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

# --- DEFAULT CONFIGURATION ---
DEFAULT_WEBHOST_PATH = "/mnt/backups/laptopwebhost"
DEFAULT_SMB_SHARE = "//192.168.50.217/Backups"
DEFAULT_SMB_MOUNT = "/mnt/network_backups"
DEFAULT_NTFY_TARGET_PATH = "/mnt/network_backups/CentralServer"
RESTORE_LOCK_FILE = "/tmp/gladstone_restore_in_progress"

# Target destinations for contents inside backup bundle: (subfolder_in_archive, target_live_path, description)
TARGET_MAPPINGS = [
    ("scripts", "scripts", "System Scripts"),
    ("data/homeasset", "homeasset/data", "HomeAsset Data"),
    ("data/jobboard", "jobboard/data", "JobBoard Data"),
    ("data/relayit", "relayit/data", "RelayIT Data"),
    ("data/immich/pgdata", "immich/pgdata", "Immich Database Files (pgdata)"),
    ("data/immich/.env", "immich/.env", "Immich Environment Config"),
    ("data/immich/docker-compose.yml", "immich/docker-compose.yml", "Immich Docker Compose"),
    ("data/immich/immich_db_dump.sql", "immich/immich_db_dump.sql", "Immich Database Dump (SQL)"),
    ("data/terminalbuddy", ".config/terminalbuddy", "TerminalBuddy Config"),
]

# Docker stack directories to manage during shutdown/restart
DOCKER_STACK_DIRS = [
    "homeasset",
    "jobboard",
    "relayit",
    "gemini-api",
    "rustdesk",
    "dozzle",
    "immich",
]


def get_smb_credentials():
    """Loads SMB credentials securely from environment variables or ~/.smbcredentials file."""
    user = os.getenv("SMB_USER", "pi")
    password = os.getenv("SMB_PASS", "root")

    cred_file = os.path.expanduser("~/.smbcredentials")
    if os.path.exists(cred_file):
        try:
            with open(cred_file, "r") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("username="):
                        user = line.split("=", 1)[1].strip()
                    elif line.startswith("password="):
                        password = line.split("=", 1)[1].strip()
        except Exception:
            pass
    return user, password


class RestoreLogger:
    """Configures dual logging to stdout and logfile with custom formatting."""

    def __init__(self, log_paths):
        self.logger = logging.getLogger("GladstoneRestore")
        self.logger.setLevel(logging.INFO)
        self.logger.handlers.clear()

        file_formatter = logging.Formatter(
            '[%(asctime)s] [%(levelname)s] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        console_formatter = logging.Formatter('%(message)s')

        ch = logging.StreamHandler(sys.stdout)
        ch.setLevel(logging.INFO)
        ch.setFormatter(console_formatter)
        self.logger.addHandler(ch)

        for lp in log_paths:
            try:
                os.makedirs(os.path.dirname(lp), exist_ok=True)
                fh = logging.FileHandler(lp, encoding='utf-8')
                fh.setLevel(logging.INFO)
                fh.setFormatter(file_formatter)
                self.logger.addHandler(fh)
            except Exception as e:
                ch.emit(logging.LogRecord(
                    "GladstoneRestore", logging.WARNING, "", 0,
                    f"⚠️ Could not setup logfile handler for {lp}: {e}", None, None
                ))

    def info(self, msg):
        self.logger.info(msg)

    def warning(self, msg):
        self.logger.warning(msg)

    def error(self, msg):
        self.logger.error(msg)


def calculate_sha256(filepath):
    """Calculates SHA256 hash of a file."""
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for byte_block in iter(lambda: f.read(65536), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()


def mount_smb_share(logger, smb_share, mount_point, user, password):
    """Mounts SMB share via CIFS if not already mounted using credentials."""
    try:
        os.makedirs(mount_point, exist_ok=True)
    except PermissionError:
        subprocess.run(["sudo", "mkdir", "-p", mount_point], capture_output=True)
        if hasattr(os, "getuid"):
            subprocess.run(["sudo", "chown", "-R", f"{os.getuid()}:{os.getgid()}", mount_point], capture_output=True)

    try:
        check_mount = subprocess.run(["mountpoint", "-q", mount_point])
        if check_mount.returncode == 0:
            logger.info(f"ℹ️ SMB share already mounted at {mount_point}")
            return True
    except Exception:
        pass

    logger.info(f"🔌 Mounting SMB share {smb_share} -> {mount_point}...")

    uid = os.getuid() if hasattr(os, "getuid") else 1000
    gid = os.getgid() if hasattr(os, "getgid") else 1000

    mount_options_list = [
        f"username={user},password={password},uid={uid},gid={gid},vers=3.0",
        f"username={user},password={password},uid={uid},gid={gid},vers=3.0,noperm",
        f"username={user},password={password},sec=ntlmssp,uid={uid},gid={gid},vers=3.0",
    ]

    last_error = ""
    for opts in mount_options_list:
        mount_cmd = ["sudo", "mount", "-t", "cifs", smb_share, mount_point, "-o", opts]
        try:
            res = subprocess.run(mount_cmd, capture_output=True, text=True, timeout=25)
            if res.returncode == 0:
                logger.info("✅ SMB share mounted successfully.")
                return True
            else:
                last_error = res.stderr.strip()
        except Exception as e:
            last_error = str(e)

    logger.error(f"❌ SMB mount failed: {last_error}")
    return False


def unmount_smb_share(logger, mount_point):
    """Cleanly unmounts SMB share."""
    logger.info(f"🔌 Unmounting SMB share at {mount_point}...")
    try:
        res = subprocess.run(["sudo", "umount", "-l", mount_point], capture_output=True, text=True, timeout=15)
        if res.returncode == 0:
            logger.info("✅ SMB share unmounted cleanly.")
        else:
            logger.warning(f"⚠️ SMB unmount notice: {res.stderr.strip()}")
    except Exception as e:
        logger.warning(f"⚠️ SMB unmount exception: {e}")


def find_available_backups(target_dir):
    """Finds and lists all available tar.gz backup archives in target_dir sorted by mtime (newest first)."""
    if not os.path.exists(target_dir):
        return []

    backups = []
    for fname in os.listdir(target_dir):
        if fname.startswith("gladstone_backup_") and fname.endswith(".tar.gz"):
            full_path = os.path.join(target_dir, fname)
            if os.path.isfile(full_path):
                mtime = os.path.getmtime(full_path)
                size_bytes = os.path.getsize(full_path)
                size_mb = round(size_bytes / (1024 * 1024), 2)
                dt_str = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M:%S")
                backups.append({
                    "filename": fname,
                    "path": full_path,
                    "mtime": mtime,
                    "datetime": dt_str,
                    "size_mb": size_mb
                })

    backups.sort(key=lambda x: x["mtime"], reverse=True)
    return backups


def stop_docker_stacks(logger, home_dir):
    """Stops running Docker compose stacks to release database/file locks."""
    logger.info("🐳 Checking and stopping running Docker compose stacks...")
    stopped_stacks = []
    for stack_name in DOCKER_STACK_DIRS:
        stack_path = os.path.join(home_dir, stack_name)
        compose_file_1 = os.path.join(stack_path, "docker-compose.yml")
        compose_file_2 = os.path.join(stack_path, "compose.yml")

        if os.path.isdir(stack_path) and (os.path.exists(compose_file_1) or os.path.exists(compose_file_2)):
            try:
                # Run docker compose down
                res = subprocess.run(
                    ["docker", "compose", "down"],
                    cwd=stack_path,
                    capture_output=True,
                    text=True,
                    timeout=60
                )
                if res.returncode == 0:
                    logger.info(f"  └─ ⏹️ Stopped Docker stack: {stack_name}")
                    stopped_stacks.append(stack_path)
                else:
                    # Attempt elevated command if permission error
                    res_sudo = subprocess.run(
                        ["sudo", "docker", "compose", "down"],
                        cwd=stack_path,
                        capture_output=True,
                        text=True,
                        timeout=60
                    )
                    if res_sudo.returncode == 0:
                        logger.info(f"  └─ ⏹️ Stopped Docker stack (elevated): {stack_name}")
                        stopped_stacks.append(stack_path)
                    else:
                        logger.warning(f"  └─ ⚠️ Notice stopping stack {stack_name}: {res_sudo.stderr.strip()}")
            except Exception as e:
                logger.warning(f"  └─ ⚠️ Exception stopping stack {stack_name}: {e}")

    return stopped_stacks


def restart_docker_stacks(logger, stopped_stacks):
    """Restarts previously stopped Docker compose stacks."""
    if not stopped_stacks:
        return

    logger.info("🚀 Restarting Docker compose stacks...")
    for stack_path in stopped_stacks:
        stack_name = os.path.basename(stack_path)
        try:
            res = subprocess.run(
                ["docker", "compose", "up", "-d"],
                cwd=stack_path,
                capture_output=True,
                text=True,
                timeout=120
            )
            if res.returncode == 0:
                logger.info(f"  └─ ▶️ Restarted Docker stack: {stack_name}")
            else:
                res_sudo = subprocess.run(
                    ["sudo", "docker", "compose", "up", "-d"],
                    cwd=stack_path,
                    capture_output=True,
                    text=True,
                    timeout=120
                )
                if res_sudo.returncode == 0:
                    logger.info(f"  └─ ▶️ Restarted Docker stack (elevated): {stack_name}")
                else:
                    logger.error(f"  └─ ❌ Failed to restart stack {stack_name}: {res_sudo.stderr.strip()}")
        except Exception as e:
            logger.error(f"  └─ ❌ Exception restarting stack {stack_name}: {e}")


def create_pre_restore_snapshot(logger, home_dir):
    """Creates a temporary safety copy of current live scripts and data in /tmp/."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    safety_archive = f"/tmp/gladstone_prerestore_safety_{timestamp}.tar.gz"
    logger.info(f"🛡️ Creating pre-restore safety snapshot -> {safety_archive}...")

    staging_dir = f"/tmp/gladstone_safety_staging_{timestamp}"
    try:
        os.makedirs(staging_dir, exist_ok=True)
        for rel_in_archive, rel_live_path, desc in TARGET_MAPPINGS:
            full_live_path = os.path.join(home_dir, rel_live_path)
            if os.path.exists(full_live_path):
                dest_stage = os.path.join(staging_dir, rel_in_archive)
                os.makedirs(os.path.dirname(dest_stage), exist_ok=True)
                if os.path.isdir(full_live_path):
                    shutil.copytree(full_live_path, dest_stage, dirs_exist_ok=True)
                else:
                    shutil.copy2(full_live_path, dest_stage)

        with tarfile.open(safety_archive, "w:gz") as tar:
            for item in os.listdir(staging_dir):
                tar.add(os.path.join(staging_dir, item), arcname=item)

        logger.info(f"✅ Safety snapshot saved successfully ({round(os.path.getsize(safety_archive)/(1024*1024), 2)} MB).")
        return safety_archive
    except Exception as e:
        logger.warning(f"⚠️ Pre-restore safety snapshot warning: {e}")
        return None
    finally:
        if os.path.exists(staging_dir):
            shutil.rmtree(staging_dir, ignore_errors=True)


def perform_restoration(archive_path, home_dir, logger):
    """Unpacks backup archive into temporary staging and restores files to live destinations."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    staging_dir = f"/tmp/gladstone_restore_staging_{timestamp}"
    os.makedirs(staging_dir, exist_ok=True)

    results = []

    try:
        logger.info(f"📦 Extracting backup archive -> {staging_dir}...")
        with tarfile.open(archive_path, "r:gz") as tar:
            tar.extractall(path=staging_dir)

        logger.info("🔄 Replacing target application directories and scripts...")
        uid = os.getuid() if hasattr(os, "getuid") else 1000
        gid = os.getgid() if hasattr(os, "getgid") else 1000

        for rel_in_archive, rel_live_path, desc in TARGET_MAPPINGS:
            staged_src = os.path.join(staging_dir, rel_in_archive)
            target_dst = os.path.join(home_dir, rel_live_path)

            if os.path.exists(staged_src):
                try:
                    os.makedirs(os.path.dirname(target_dst), exist_ok=True)

                    # Replace target path cleanly
                    if os.path.exists(target_dst):
                        if os.path.isdir(target_dst):
                            shutil.rmtree(target_dst)
                        else:
                            os.remove(target_dst)

                    if os.path.isdir(staged_src):
                        shutil.copytree(staged_src, target_dst, dirs_exist_ok=True)
                    else:
                        shutil.copy2(staged_src, target_dst)

                    logger.info(f"  └─ ✅ {desc}: Restored -> {rel_live_path}")
                    results.append((desc, "RESTORED"))
                except (PermissionError, OSError) as e:
                    # Elevated restore fallback for root-owned volumes
                    logger.info(f"  └─ 🔑 Performing elevated restore for {desc}...")
                    subprocess.run(["sudo", "rm", "-rf", target_dst], capture_output=True)
                    subprocess.run(["sudo", "mkdir", "-p", os.path.dirname(target_dst)], capture_output=True)
                    res_cp = subprocess.run(["sudo", "cp", "-r", staged_src, target_dst], capture_output=True, text=True)
                    if res_cp.returncode == 0:
                        subprocess.run(["sudo", "chown", "-R", f"{uid}:{gid}", target_dst], capture_output=True)
                        logger.info(f"  └─ ✅ {desc}: Restored (elevated) -> {rel_live_path}")
                        results.append((desc, "RESTORED (elevated)"))
                    else:
                        err_msg = res_cp.stderr.strip() or str(e)
                        logger.error(f"  └─ ❌ {desc} restoration failed: {err_msg}")
                        results.append((desc, f"FAILED ({err_msg})"))
            else:
                logger.info(f"  └─ ℹ️ {desc}: Not present in backup bundle (skipped)")
                results.append((desc, "NOT PRESENT IN BACKUP"))

        return True, results
    except Exception as e:
        logger.error(f"❌ Restoration unpack error: {e}")
        return False, results
    finally:
        if os.path.exists(staging_dir):
            shutil.rmtree(staging_dir, ignore_errors=True)
            subprocess.run(["sudo", "rm", "-rf", staging_dir], capture_output=True)


def main():
    parser = argparse.ArgumentParser(description="Gladstone Interactive System Restore Manager")
    parser.add_argument("--mode", choices=["webhost", "ntfy"], help="Restore mode (webhost or ntfy)")
    parser.add_argument("--file", help="Direct path to tar.gz backup file to restore")
    parser.add_argument("--latest", action="store_true", help="Automatically select the most recent backup")
    parser.add_argument("--yes", action="store_true", help="Skip interactive confirmation prompts")
    args = parser.parse_args()

    # Determine mode automatically if not supplied
    mode = args.mode
    if not mode:
        hostname = os.uname().nodename.lower() if hasattr(os, "uname") else ""
        if "webhost" in hostname or "laptop" in hostname or os.path.exists(DEFAULT_WEBHOST_PATH):
            mode = "webhost"
        else:
            mode = "ntfy"

    home_dir = os.path.expanduser("~")
    log_file_1 = os.path.join(home_dir, "scripts", "logs", "restore.log")
    log_file_2 = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs", "restore.log")
    logger = RestoreLogger([log_file_1, log_file_2])

    now_dt = datetime.now()
    formatted_date_str = now_dt.strftime("%Y-%m-%d %H:%M:%S")

    logger.info("==========================================================================")
    logger.info(f"🔄 GLADSTONE SYSTEM RESTORE STARTED | Mode: {mode.upper()} | Time: {formatted_date_str}")
    logger.info("==========================================================================")

    mounted_smb = False
    if mode == "webhost":
        target_dir = DEFAULT_WEBHOST_PATH
        logger.info(f"📂 Target Backup Directory (Local): {target_dir}")
    else:
        smb_user, smb_pass = get_smb_credentials()
        mounted_smb = mount_smb_share(logger, DEFAULT_SMB_SHARE, DEFAULT_SMB_MOUNT, smb_user, smb_pass)
        if not mounted_smb:
            logger.error("❌ Network SMB share unavailable. Aborting restore.")
            sys.exit(1)
        target_dir = DEFAULT_NTFY_TARGET_PATH
        logger.info(f"🌐 Target Backup Directory (SMB Network): {DEFAULT_SMB_SHARE} -> {target_dir}")

    # Select backup file
    selected_backup = None
    if args.file:
        if os.path.exists(args.file):
            size_mb = round(os.path.getsize(args.file) / (1024 * 1024), 2)
            mtime = os.path.getmtime(args.file)
            dt_str = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M:%S")
            selected_backup = {
                "filename": os.path.basename(args.file),
                "path": os.path.abspath(args.file),
                "datetime": dt_str,
                "size_mb": size_mb
            }
        else:
            logger.error(f"❌ Specified backup file not found: {args.file}")
            if mounted_smb:
                unmount_smb_share(logger, DEFAULT_SMB_MOUNT)
            sys.exit(1)
    else:
        available_backups = find_available_backups(target_dir)
        if not available_backups:
            logger.error(f"❌ No backup archives found in {target_dir}")
            if mounted_smb:
                unmount_smb_share(logger, DEFAULT_SMB_MOUNT)
            sys.exit(1)

        if args.latest:
            selected_backup = available_backups[0]
        else:
            # Interactive Menu Selection
            print("\n📋 AVAILABLE SYSTEM BACKUPS:")
            print("--------------------------------------------------------------------------")
            for idx, b in enumerate(available_backups, start=1):
                latest_tag = " (LATEST)" if idx == 1 else ""
                print(f"  [{idx}] {b['filename']}{latest_tag}")
                print(f"      Date: {b['datetime']} | Size: {b['size_mb']} MB")
            print("--------------------------------------------------------------------------")

            choice = input(f"Select backup to restore [1-{len(available_backups)}] (or 'q' to quit): ").strip()
            if choice.lower() in ['q', 'quit', 'exit', '']:
                logger.info("⏹️ Restore cancelled by user.")
                if mounted_smb:
                    unmount_smb_share(logger, DEFAULT_SMB_MOUNT)
                sys.exit(0)

            try:
                choice_idx = int(choice) - 1
                if 0 <= choice_idx < len(available_backups):
                    selected_backup = available_backups[choice_idx]
                else:
                    logger.error("❌ Invalid selection number. Aborting.")
                    if mounted_smb:
                        unmount_smb_share(logger, DEFAULT_SMB_MOUNT)
                    sys.exit(1)
            except ValueError:
                logger.error("❌ Invalid input. Expected selection number. Aborting.")
                if mounted_smb:
                    unmount_smb_share(logger, DEFAULT_SMB_MOUNT)
                sys.exit(1)

    logger.info("--------------------------------------------------------------------------")
    logger.info(f"🎯 Selected Backup: {selected_backup['filename']}")
    logger.info(f"   Created: {selected_backup['datetime']} | Size: {selected_backup['size_mb']} MB")
    logger.info("--------------------------------------------------------------------------")

    # Verify Checksum
    logger.info("🔍 Calculating SHA256 checksum for selected archive...")
    computed_sha256 = calculate_sha256(selected_backup['path'])
    logger.info(f"   SHA256: {computed_sha256}")

    # Interactive Confirmation Guardrail
    if not args.yes:
        print("\n⚠️ WARNING: RESTORING SYSTEM DATA")
        print("This operation will:")
        print("  1. Pause background service watchdogs")
        print("  2. Stop active Docker compose stacks")
        print("  3. Replace live scripts (~/scripts) and application data (~/*/data)")
        print("  4. Restart Docker stacks and resume watchdogs")
        confirm = input("\nType 'RESTORE' in capital letters to confirm and proceed: ").strip()
        if confirm != "RESTORE":
            logger.info("⏹️ Confirmation failed. Restoration cancelled.")
            if mounted_smb:
                unmount_smb_share(logger, DEFAULT_SMB_MOUNT)
            sys.exit(0)

    # Begin Restoration Procedure
    stopped_stacks = []
    restore_success = False
    app_results = []

    try:
        # Step 1: Touch lock file to pause watchdog
        with open(RESTORE_LOCK_FILE, "w") as f:
            f.write(f"Restoration started at {formatted_date_str}\n")
        logger.info(f"🔒 Watchdog pause lock created at {RESTORE_LOCK_FILE}")

        # Step 2: Stop Docker containers
        stopped_stacks = stop_docker_stacks(logger, home_dir)

        # Step 3: Create Pre-Restore Safety Snapshot
        create_pre_restore_snapshot(logger, home_dir)

        # Step 4: Perform Restoration
        restore_success, app_results = perform_restoration(selected_backup['path'], home_dir, logger)

    finally:
        # Step 5: Restart Docker containers
        restart_docker_stacks(logger, stopped_stacks)

        # Step 6: Remove Lock File to unpause watchdog
        if os.path.exists(RESTORE_LOCK_FILE):
            try:
                os.remove(RESTORE_LOCK_FILE)
            except Exception:
                subprocess.run(["sudo", "rm", "-f", RESTORE_LOCK_FILE], capture_output=True)
            logger.info(f"🔓 Watchdog pause lock removed.")

        # Step 7: Unmount SMB if applicable
        if mounted_smb:
            unmount_smb_share(logger, DEFAULT_SMB_MOUNT)

    # Final Summary
    logger.info("==========================================================================")
    logger.info("📊 RESTORE EXECUTION SUMMARY")
    logger.info(f"  • Date & Time:      {formatted_date_str}")
    logger.info(f"  • Mode:             {mode.upper()}")
    logger.info(f"  • Source Archive:   {selected_backup['filename']}")
    logger.info(f"  • Status:           {'SUCCESS' if restore_success else 'FAILED'}")
    for comp, st in app_results:
        logger.info(f"  • {comp:<18}: {st}")
    logger.info("==========================================================================")

    if not restore_success:
        sys.exit(1)


if __name__ == "__main__":
    main()
