#!/usr/bin/env python3
"""
=============================================================================
GLADSTONE SYSTEM BACKUP MANAGER (backup_manager.py)
=============================================================================
Role-aware, multi-target backup system with sophisticated logging, SHA256
verification, disk space diagnostics, and retention rotation.

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

# Data directories to include if present
DATA_SOURCES = [
    ("/home/pi/homeasset/data", "HomeAsset Data"),
    ("/home/pi/jobboard/data", "JobBoard Data"),
    ("/home/pi/relayit/data", "RelayIT Data"),
    ("/home/pi/.config/terminalbuddy", "TerminalBuddy Config"),
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
        ch.setLevel(logging.INFO)
        ch.setFormatter(console_formatter)
        self.logger.addHandler(ch)

        # File Handlers
        for lp in log_paths:
            try:
                os.makedirs(os.path.dirname(lp), exist_ok=True)
                fh = logging.FileHandler(lp, encoding='utf-8')
                fh.setLevel(logging.INFO)
                fh.setFormatter(file_formatter)
                self.logger.addHandler(fh)
            except Exception as e:
                ch.emit(logging.LogRecord(
                    "GladstoneBackup", logging.WARNING, "", 0,
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


def get_system_diagnostics():
    """Gathers system storage and diagnostic information."""
    diagnostics = {}
    try:
        total, used, free = shutil.disk_usage("/")
        diagnostics["disk_total_gb"] = round(total / (1024**3), 2)
        diagnostics["disk_used_gb"] = round(used / (1024**3), 2)
        diagnostics["disk_free_gb"] = round(free / (1024**3), 2)
    except Exception:
        diagnostics["disk_free_gb"] = "Unknown"
    
    diagnostics["hostname"] = os.uname().nodename if hasattr(os, "uname") else "Unknown"
    return diagnostics


def mount_smb_share(logger, smb_share, mount_point, user, password):
    """Mounts SMB share via CIFS if not already mounted using credentials."""
    try:
        os.makedirs(mount_point, exist_ok=True)
    except PermissionError:
        subprocess.run(["sudo", "mkdir", "-p", mount_point], capture_output=True)
        if hasattr(os, "getuid"):
            subprocess.run(["sudo", "chown", "-R", f"{os.getuid()}:{os.getgid()}", mount_point], capture_output=True)

    # Check if already mounted
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


def create_tar_gz(source_dir, output_file, exclude_list, logger):
    """Creates a compressed tar.gz archive of source_dir with exclusions."""
    def filter_function(tarinfo):
        name = os.path.basename(tarinfo.name)
        for pattern in exclude_list:
            if pattern.startswith("*"):
                if name.endswith(pattern[1:]):
                    return None
            elif name == pattern or pattern in tarinfo.name.split('/'):
                return None
        return tarinfo

    logger.info(f"📦 Archiving {source_dir} -> {output_file}...")
    with tarfile.open(output_file, "w:gz") as tar:
        tar.add(source_dir, arcname=os.path.basename(source_dir), filter=filter_function)
    return os.path.exists(output_file) and os.path.getsize(output_file) > 0


def copy_extra_data(dest_dir, logger):
    """Copies application data paths into destination backup folder with elevated fallback for docker volumes."""
    results = []
    for path, description in DATA_SOURCES:
        if os.path.exists(path):
            basename = os.path.basename(path.rstrip('/'))
            parent_name = os.path.basename(os.path.dirname(path.rstrip('/')))
            dest_name = f"{parent_name}_{basename}_" + datetime.now().strftime("%Y%m%d_%H%M%S")
            target_path = os.path.join(dest_dir, dest_name)
            try:
                if os.path.isdir(path):
                    shutil.copytree(path, target_path, dirs_exist_ok=True)
                else:
                    shutil.copy2(path, target_path)
                logger.info(f"  └─ ✅ {description}: Backed up -> {dest_name}")
                results.append((description, "SUCCESS"))
            except (PermissionError, OSError) as e:
                # Fallback to sudo cp -r for docker container volumes owned by root/other users
                res = subprocess.run(["sudo", "cp", "-r", path, target_path], capture_output=True, text=True)
                if res.returncode == 0:
                    logger.info(f"  └─ ✅ {description}: Backed up (elevated) -> {dest_name}")
                    results.append((description, "SUCCESS"))
                else:
                    err_msg = res.stderr.strip() or str(e)
                    logger.error(f"  └─ ❌ {description} failed: {err_msg}")
                    results.append((description, f"FAILED ({err_msg})"))
        else:
            results.append((description, "SKIPPED (Not Present)"))
    return results


def rotate_backups(target_dir, prefix, keep_count, logger):
    """Rotates backup files in target_dir keeping keep_count most recent."""
    logger.info(f"🧹 Performing backup rotation in {target_dir} (Keeping top {keep_count})...")
    try:
        files = [
            os.path.join(target_dir, f) for f in os.listdir(target_dir)
            if f.startswith(prefix)
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
                    logger.info(f"  └─ 🗑️ Pruned old backup: {os.path.basename(old_file)}")
                except Exception as e:
                    # Fallback to sudo rm for docker-created backup directories
                    subprocess.run(["sudo", "rm", "-rf", old_file], capture_output=True)
                    logger.info(f"  └─ 🗑️ Pruned old backup (elevated): {os.path.basename(old_file)}")
        else:
            logger.info(f"  └─ Total backups ({len(files)}) within retention limit ({keep_count}).")
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
    log_file_1 = os.path.join(home_dir, "scripts", "logs", "pi_backup.log")
    log_file_2 = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs", "pi_backup.log")
    logger = BackupLogger([log_file_1, log_file_2])

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    logger.info("==========================================================================")
    logger.info(f"📦 GLADSTONE BACKUP STARTED | Mode: {mode.upper()} | Timestamp: {timestamp}")
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

    # Step 1: Create Scripts Archive
    source_scripts = os.path.join(home_dir, "scripts")
    archive_name = f"gladstone_backup_{mode}_{timestamp}.tar.gz"
    temp_archive = os.path.join("/tmp", archive_name) if mode == "ntfy" else os.path.join(target_dir, archive_name)
    final_archive = os.path.join(target_dir, archive_name)

    success = False
    checksum = "N/A"
    archive_size_mb = 0

    if not args.dry_run:
        if os.path.exists(source_scripts):
            if create_tar_gz(source_scripts, temp_archive, SCRIPT_EXCLUDES, logger):
                archive_size_mb = round(os.path.getsize(temp_archive) / (1024 * 1024), 2)
                checksum = calculate_sha256(temp_archive)
                logger.info(f"✅ Archive created successfully ({archive_size_mb} MB | SHA256: {checksum[:12]}...)")

                if mode == "ntfy":
                    logger.info(f"🚚 Transferring archive to SMB share -> {final_archive}...")
                    shutil.copy2(temp_archive, final_archive)
                    os.remove(temp_archive)
                    dest_checksum = calculate_sha256(final_archive)
                    if dest_checksum == checksum:
                        logger.info("🔒 Checksum verified: Transfer integrity confirmed.")
                        success = True
                    else:
                        logger.error("❌ Checksum mismatch after transfer!")
                else:
                    success = True
            else:
                logger.error("❌ Failed to create tar archive.")
        else:
            logger.error(f"❌ Source scripts directory not found: {source_scripts}")
    else:
        logger.info(" DRY-RUN enabled: Skipping file creation.")
        success = True

    # Step 2: Application Data Backups
    app_results = []
    if success and not args.dry_run:
        logger.info("📋 Backing up application stack data...")
        app_results = copy_extra_data(target_dir, logger)

    # Step 3: Rotation
    if success and not args.dry_run:
        rotate_backups(target_dir, "gladstone_backup_", args.retention, logger)

    # Step 4: Cleanup Mount if applicable
    if mounted_smb:
        unmount_smb_share(logger, DEFAULT_SMB_MOUNT)

    # Execution Summary
    logger.info("--------------------------------------------------------------------------")
    logger.info("📊 BACKUP EXECUTION SUMMARY")
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
