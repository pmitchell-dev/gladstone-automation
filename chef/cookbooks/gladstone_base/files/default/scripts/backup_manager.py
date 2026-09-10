#!/usr/bin/env python3
"""
=============================================================================
GLADSTONE SYSTEM BACKUP MANAGER (backup_manager.py)
=============================================================================
Role-aware, multi-target backup system with single-archive bundling, SHA256
verification, disk space diagnostics, and retention rotation.

Bundles all scripts and application stack data into a SINGLE compressed
tar.gz file per backup execution.

Targets:
  - Webhost (--mode webhost): Saves locally to /mnt/backups/laptopwebhost
  - NTFY Hub (--mode ntfy):   Saves to //192.168.50.217/Backups/ -> /mnt/network_backups/CentralServer
                              utilizing credentials from environment or ~/.smbcredentials
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

RETENTION_COUNT = 7  # Keep top 7 daily backups

# Data directories to include if present: (path, target_subfolder_name, description)
DATA_SOURCES = [
    (os.path.expanduser("~/homeasset/data"), "data/homeasset", "HomeAsset Data"),
    (os.path.expanduser("~/jobboard/data"), "data/jobboard", "JobBoard Data"),
    (os.path.expanduser("~/gladstone-automation"), "data/gladstone-automation", "Gladstone IaC Repository"),
    (os.path.expanduser("~/.config/terminalbuddy"), "data/terminalbuddy", "TerminalBuddy Config"),
]

# Exclude patterns when backing up scripts directory
SCRIPT_EXCLUDES = [
    "backup",
    "logs",
    ".git",
    "node_modules",
    "__pycache__",
    "*.pyc"
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


class BackupLogger:
    """Configures dual logging to stdout and file with custom formatting."""

    def __init__(self, log_paths):
        self.logger = logging.getLogger("GladstoneBackup")
        self.logger.setLevel(logging.INFO)
        self.logger.handlers.clear()

        # Formatters
        file_formatter = logging.Formatter(
            '[%(asctime)s] [%(levelname)s] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        console_formatter = logging.Formatter('%(message)s')

        # Console Handler
        ch = logging.StreamHandler(sys.stdout)
        ch.setFormatter(console_formatter)
        self.logger.addHandler(ch)

        # File Handlers
        for log_path in log_paths:
            try:
                os.makedirs(os.path.dirname(log_path), exist_ok=True)
                fh = logging.FileHandler(log_path, encoding='utf-8')
                fh.setFormatter(file_formatter)
                self.logger.addHandler(fh)
            except Exception:
                pass

    def info(self, msg):
        self.logger.info(msg)

    def warning(self, msg):
        self.logger.warning(msg)

    def error(self, msg):
        self.logger.error(msg)


def check_disk_space(target_path, logger, required_mb=500):
    """Verifies sufficient disk space exists at target path."""
    try:
        os.makedirs(target_path, exist_ok=True)
        stat = shutil.disk_usage(target_path)
        free_mb = stat.free / (1024 * 1024)
        logger.info(f"📊 Target disk space check ({target_path}): {free_mb:.2f} MB free.")
        if free_mb < required_mb:
            logger.warning(f"⚠️ Low disk space alert: Less than {required_mb} MB available at {target_path}!")
            return False
        return True
    except Exception as e:
        logger.warning(f"⚠️ Unable to check disk space at {target_path}: {e}")
        return True


def calculate_sha256(file_path):
    """Calculates SHA256 checksum of a file."""
    sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            sha256.update(chunk)
    return sha256.hexdigest()


def mount_smb_share(smb_share, mount_point, user, password, logger):
    """Mounts SMB share to local mount_point using cifs-utils."""
    os.makedirs(mount_point, exist_ok=True)
    
    # Check if already mounted
    res = subprocess.run(["mountpoint", "-q", mount_point], capture_output=True)
    if res.returncode == 0:
        logger.info(f"✅ SMB share already mounted at {mount_point}")
        return True

    logger.info(f"🔌 Mounting SMB share {smb_share} to {mount_point}...")
    mount_cmd = [
        "sudo", "mount", "-t", "cifs",
        smb_share, mount_point,
        "-o", f"username={user},password={password},uid={os.getuid()},gid={os.getgid()},file_mode=0777,dir_mode=0777,nobrl"
    ]
    
    last_error = ""
    for attempt in range(1, 4):
        res = subprocess.run(mount_cmd, capture_output=True, text=True, timeout=30)
        if res.returncode == 0:
            logger.info("✅ SMB share mounted successfully.")
            return True
        last_error = res.stderr.strip()
        logger.warning(f"⚠️ SMB mount attempt {attempt} failed: {last_error}")

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


def stage_backup_contents(staging_dir, logger):
    """Copies scripts and application stack data into staging directory structure."""
    home_dir = os.path.expanduser("~")
    source_scripts = os.path.join(home_dir, "scripts")

    # 1. Copy Scripts
    if os.path.exists(source_scripts):
        scripts_stage = os.path.join(staging_dir, "scripts")
        try:
            def ignore_func(dir_path, names):
                ignored = set()
                for n in names:
                    for pat in SCRIPT_EXCLUDES:
                        if pat.startswith("*") and n.endswith(pat[1:]):
                            ignored.add(n)
                        elif n == pat:
                            ignored.add(n)
                return ignored

            shutil.copytree(source_scripts, scripts_stage, ignore=ignore_func, dirs_exist_ok=True)
            logger.info("  └─ ✅ System Scripts: Staged -> scripts/")
        except Exception as e:
            logger.warning(f"  └─ ⚠️ Copying scripts warning: {e}")

    # 2. Dump Immich PostgreSQL database if running
    immich_dir = os.path.expanduser("~/immich")
    if os.path.exists(immich_dir):
        immich_target = os.path.join(staging_dir, "data", "immich")
        os.makedirs(immich_target, exist_ok=True)
        dump_path = os.path.join(immich_target, "immich_db_dump.sql")
        
        try:
            res = subprocess.run(
                ["docker", "exec", "immich_postgres", "pg_dumpall", "-U", "postgres"],
                capture_output=True, text=True, timeout=60
            )
            if res.returncode != 0:
                res = subprocess.run(
                    ["docker", "exec", "immich-postgres", "pg_dumpall", "-U", "postgres"],
                    capture_output=True, text=True, timeout=60
                )
            if res.returncode == 0 and res.stdout.strip():
                with open(dump_path, "w", encoding="utf-8") as f:
                    f.write(res.stdout)
                logger.info("  └─ ✅ Immich Database Dump (SQL): Staged -> data/immich/immich_db_dump.sql")
        except Exception as e:
            logger.warning(f"  └─ ⚠️ Immich pg_dump notice: {e}")

    # 3. Copy App Data Sources
    app_summary = []
    for source_path, dest_rel_path, description in DATA_SOURCES:
        if os.path.exists(source_path):
            target_stage = os.path.join(staging_dir, dest_rel_path)
            try:
                os.makedirs(os.path.dirname(target_stage), exist_ok=True)
                if os.path.isdir(source_path):
                    shutil.copytree(source_path, target_stage, dirs_exist_ok=True)
                else:
                    shutil.copy2(source_path, target_stage)
                logger.info(f"  └─ ✅ {description}: Staged -> {dest_rel_path}")
                app_summary.append((description, "SUCCESS"))
            except (PermissionError, OSError) as e:
                # Fallback elevated copy for docker volumes owned by root
                os.makedirs(os.path.dirname(target_stage), exist_ok=True)
                res = subprocess.run(["sudo", "cp", "-r", source_path, target_stage], capture_output=True, text=True)
                if res.returncode == 0:
                    # Fix permissions on staged files so user can tar them
                    subprocess.run(["sudo", "chown", "-R", f"{os.getuid()}:{os.getgid()}", target_stage], capture_output=True)
                    logger.info(f"  └─ ✅ {description}: Staged (elevated) -> {dest_rel_path}")
                    app_summary.append((description, "SUCCESS"))
                else:
                    err_msg = res.stderr.strip() or str(e)
                    logger.error(f"  └─ ❌ {description} failed to stage: {err_msg}")
                    app_summary.append((description, f"FAILED ({err_msg})"))
        else:
            app_summary.append((description, "SKIPPED (Not Present)"))

    return app_summary


def create_single_tar_gz(staging_dir, output_file, logger):
    """Compresses the staging directory into a single tar.gz file."""
    logger.info(f"📦 Archiving all components into single bundle -> {output_file}...")
    with tarfile.open(output_file, "w:gz") as tar:
        for item in os.listdir(staging_dir):
            full_path = os.path.join(staging_dir, item)
            tar.add(full_path, arcname=item)
    return os.path.exists(output_file) and os.path.getsize(output_file) > 0


def rotate_backups(target_dir, prefix, keep_count, logger):
    """Rotates backup files in target_dir keeping keep_count most recent."""
    logger.info(f"🧹 Performing backup rotation in {target_dir} (Keeping top {keep_count})...")
    try:
        files = [
            os.path.join(target_dir, f) for f in os.listdir(target_dir)
            if f.startswith(prefix) and f.endswith(".tar.gz")
        ]
        files.sort(key=os.path.getmtime, reverse=True)

        if len(files) > keep_count:
            to_remove = files[keep_count:]
            for old_file in to_remove:
                try:
                    if os.path.isdir(old_file):
                        shutil.rmtree(old_file)
                    else:
                        os.remove(old_file)
                    logger.info(f"  └─ 🗑️ Pruned old backup archive: {os.path.basename(old_file)}")
                except Exception as e:
                    subprocess.run(["sudo", "rm", "-rf", old_file], capture_output=True)
                    logger.info(f"  └─ 🗑️ Pruned old backup archive (elevated): {os.path.basename(old_file)}")
        else:
            logger.info(f"  └─ Total backup archives ({len(files)}) within retention limit ({keep_count}).")
    except Exception as e:
        logger.error(f"❌ Rotation error: {e}")


def main():
    parser = argparse.ArgumentParser(description="Gladstone Server Backup Manager")
    parser.add_argument("--mode", choices=["webhost", "ntfy"], help="Backup mode (webhost or ntfy)")
    parser.add_argument("--retention", type=int, default=RETENTION_COUNT, help="Number of backups to keep")
    parser.add_argument("--dry-run", action="store_true", help="Simulate backup without writing")
    args = parser.parse_args()

    # Determine mode automatically if not supplied
    mode = args.mode
    if not mode:
        hostname = os.uname().nodename.lower() if hasattr(os, "uname") else ""
        if "webhost" in hostname or "laptop" in hostname or os.path.exists(DEFAULT_WEBHOST_PATH):
            mode = "webhost"
        else:
            mode = "ntfy"

    # Log setup
    home_dir = os.path.expanduser("~")
    log_file_1 = os.path.join(home_dir, "scripts", "logs", "backup.log")
    log_file_2 = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs", "backup.log")
    logger = BackupLogger([log_file_1, log_file_2])

    now_dt = datetime.now()
    timestamp = now_dt.strftime("%Y%m%d_%H%M%S")
    formatted_date_str = now_dt.strftime("%Y-%m-%d %H:%M:%S")

    logger.info("==========================================================================")
    logger.info(f"📦 GLADSTONE BACKUP STARTED | Mode: {mode.upper()} | Timestamp: {timestamp} ({formatted_date_str})")
    logger.info("==========================================================================")

    # Diagnostics
    diag = get_system_diagnostics()
    logger.info(f"💻 Host: {diag['hostname']} | Free Disk: {diag['disk_free_gb']} GB")

    mounted_smb = False
    if mode == "webhost":
        target_dir = DEFAULT_WEBHOST_PATH
        try:
            os.makedirs(target_dir, exist_ok=True)
            logger.info(f"📂 Target Directory (Local): {target_dir}")
        except PermissionError:
            subprocess.run(["sudo", "mkdir", "-p", target_dir], capture_output=True)
            if hasattr(os, "getuid"):
                subprocess.run(["sudo", "chown", "-R", f"{os.getuid()}:{os.getgid()}", target_dir], capture_output=True)
            logger.info(f"📂 Target Directory (Local): {target_dir}")
        except Exception as e:
            logger.error(f"❌ Cannot access local target directory {target_dir}: {e}")
            sys.exit(1)
    else:  # ntfy mode
        smb_user, smb_pass = get_smb_credentials()
        mounted_smb = mount_smb_share(logger, DEFAULT_SMB_SHARE, DEFAULT_SMB_MOUNT, smb_user, smb_pass)
        if not mounted_smb:
            logger.error("❌ Network SMB share unavailable. Aborting backup.")
            sys.exit(1)
        
        target_dir = DEFAULT_NTFY_TARGET_PATH
        try:
            os.makedirs(target_dir, exist_ok=True)
        except PermissionError:
            subprocess.run(["sudo", "mkdir", "-p", target_dir], capture_output=True)
            if hasattr(os, "getuid"):
                subprocess.run(["sudo", "chown", "-R", f"{os.getuid()}:{os.getgid()}", target_dir], capture_output=True)

        logger.info(f"🌐 Target Directory (SMB Network): {DEFAULT_SMB_SHARE} -> {target_dir}")

    # Archive Filenames
    archive_name = f"gladstone_backup_{mode}_{timestamp}.tar.gz"
    temp_archive = os.path.join("/tmp", archive_name)
    final_archive = os.path.join(target_dir, archive_name)
    staging_dir = os.path.join("/tmp", f"gladstone_staging_{timestamp}")

    success = False
    checksum = "N/A"
    archive_size_mb = 0
    app_results = []

    if not args.dry_run:
        try:
            # Step 1: Stage files
            os.makedirs(staging_dir, exist_ok=True)
            logger.info(f"📁 Staging scripts and application data into temporary area...")
            app_results = stage_backup_contents(staging_dir, logger)

            # Step 2: Create single bundle archive
            if create_single_tar_gz(staging_dir, temp_archive, logger):
                archive_size_mb = round(os.path.getsize(temp_archive) / (1024 * 1024), 2)
                checksum = calculate_sha256(temp_archive)
                logger.info(f"✅ Single Archive Bundle created ({archive_size_mb} MB | SHA256: {checksum[:12]}...)")

                # Move/Copy to target destination
                logger.info(f"🚚 Saving archive bundle -> {final_archive}...")
                shutil.copy2(temp_archive, final_archive)
                os.remove(temp_archive)

                dest_checksum = calculate_sha256(final_archive)
                if dest_checksum == checksum:
                    logger.info("🔒 Checksum verified: Archive bundle integrity confirmed.")
                    success = True
                else:
                    logger.error("❌ Checksum mismatch after writing to target directory!")
            else:
                logger.error("❌ Failed to create single tar archive bundle.")
        except Exception as e:
            logger.error(f"❌ Backup execution error: {e}")
        finally:
            # Clean up staging directory
            if os.path.exists(staging_dir):
                shutil.rmtree(staging_dir, ignore_errors=True)
                subprocess.run(["sudo", "rm", "-rf", staging_dir], capture_output=True)
    else:
        logger.info(" DRY-RUN enabled: Skipping archive bundle creation.")
        success = True

    # Step 3: Rotation
    if success and not args.dry_run:
        rotate_backups(target_dir, f"gladstone_backup_{mode}_", args.retention, logger)

    # Step 4: Cleanup Mount if applicable
    if mounted_smb:
        unmount_smb_share(logger, DEFAULT_SMB_MOUNT)

    # Execution Summary
    logger.info("--------------------------------------------------------------------------")
    logger.info("📊 BACKUP EXECUTION SUMMARY")
    logger.info(f"  • Date & Time:      {formatted_date_str}")
    logger.info(f"  • Mode:             {mode.upper()}")
    logger.info(f"  • Target:           {target_dir}")
    logger.info(f"  • Main Archive:     {archive_name} ({'SUCCESS' if success else 'FAILED'})")
    logger.info(f"  • Archive Size:     {archive_size_mb} MB")
    logger.info(f"  • SHA256:           {checksum}")
    for comp, st in app_results:
        logger.info(f"  • {comp:<18}: {st}")
    logger.info("==========================================================================")

    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()
