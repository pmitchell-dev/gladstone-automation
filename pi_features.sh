#!/bin/bash
# ==========================================================
# GLADSTONE DYNAMIC FEATURE SELECTOR (pi_features.sh)
# ==========================================================
# Manage enabled/disabled services & containers per server role.
# Bypasses git pulls/builds for disabled features, removes containers,
# and transfers application content/config files to external drive archive.
# ==========================================================

SCRIPT_DIR="$HOME/scripts"
ID_FILE="$HOME/.gladstone_mode"
MODE=$(cat "$ID_FILE" 2>/dev/null || echo "ntfy")
MODE=$(echo "$MODE" | tr -d '[:space:]')
CONFIG_FILE="$HOME/.gladstone_enabled_features"

# ANSI Colors
CYAN='\033[0;36m'
BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_RED='\033[1;31m'
RESET='\033[0m'

# Available features per mode
WEBHOST_FEATURES=("homeasset" "jobboard" "relayit" "gemini-api" "rustdesk" "dozzle")
NTFY_FEATURES=("simplelogin" "dozzle-agent" "ntfy_listener" "cloudflare_ddns" "printer_health")

get_mode_features() {
    if [ "$MODE" == "webhost" ]; then
        echo "${WEBHOST_FEATURES[@]}"
    else
        echo "${NTFY_FEATURES[@]}"
    fi
}

get_feature_label() {
    case "$1" in
        homeasset) echo "HomeAsset Inventory & Property Stack" ;;
        jobboard) echo "JobBoard Kanban & Application Tracker" ;;
        relayit) echo "RelayIT IT Ticket System" ;;
        gemini-api) echo "Gemini API Backend Proxy Server" ;;
        rustdesk) echo "RustDesk Remote Desktop Server" ;;
        dozzle) echo "Dozzle Centralized Log Viewer" ;;
        simplelogin) echo "SimpleLogin Email Alias Stack" ;;
        dozzle-agent) echo "Dozzle Log Agent (Hub Streamer)" ;;
        ntfy_listener) echo "Ntfy Command Listener Script Service" ;;
        cloudflare_ddns) echo "Cloudflare Dynamic DNS Updates" ;;
        printer_health) echo "Brother Printer Monitoring & Alerts" ;;
        *) echo "$1" ;;
    esac
}

init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        mkdir -p "$(dirname "$CONFIG_FILE")"
        echo "# Gladstone Enabled Features for Mode: $MODE" > "$CONFIG_FILE"
        for feat in $(get_mode_features); do
            echo "${feat}=enabled" >> "$CONFIG_FILE"
        done
        echo -e "${BOLD_GREEN}✅ Initialized feature configuration with all features enabled.${RESET}"
    fi
}

is_feature_enabled() {
    local feat="$1"
    init_config
    if grep -q "^${feat}=enabled" "$CONFIG_FILE" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

enable_feature() {
    local feat="$1"
    init_config
    sed -i "/^${feat}=/d" "$CONFIG_FILE"
    echo "${feat}=enabled" >> "$CONFIG_FILE"
    echo -e "${BOLD_GREEN}✅ Enabled feature '${feat}'.${RESET}"
}

disable_feature() {
    local feat="$1"
    init_config
    sed -i "/^${feat}=/d" "$CONFIG_FILE"
    echo "${feat}=disabled" >> "$CONFIG_FILE"
    echo -e "${BOLD_YELLOW}⚠️ Disabled feature '${feat}'.${RESET}"
}

get_external_drive_dir() {
    if [ "$MODE" == "webhost" ]; then
        if [ -d "/mnt/backups" ]; then
            echo "/mnt/backups"
        elif [ -d "/mnt/network_backups" ]; then
            echo "/mnt/network_backups"
        else
            local media_mount=$(ls -d /media/$USER/* 2>/dev/null | head -n 1)
            if [ -n "$media_mount" ] && [ -d "$media_mount" ]; then
                echo "$media_mount"
            else
                echo "$HOME/.gladstone_disabled_archive"
            fi
        fi
    else
        if [ -d "/mnt/network_backups" ]; then
            echo "/mnt/network_backups"
        elif [ -d "/mnt/backups" ]; then
            echo "/mnt/backups"
        else
            echo "$HOME/.gladstone_disabled_archive"
        fi
    fi
}

cleanup_disabled_features() {
    init_config
    local ext_drive=$(get_external_drive_dir)
    
    for feat in $(get_mode_features); do
        if ! is_feature_enabled "$feat"; then
            local app_dir="$HOME/$feat"
            # Special directory path for dozzle-agent if needed
            if [ "$feat" == "dozzle-agent" ] || [ "$feat" == "dozzle" ]; then
                app_dir="$HOME/dozzle"
            fi
            
            # Check if container or local directory exists
            local containers_running=""
            if command -v docker &>/dev/null; then
                containers_running=$(docker ps -a --filter "name=$feat" -q 2>/dev/null)
            fi

            if [ -d "$app_dir" ] || [ -n "$containers_running" ]; then
                echo -e "${BOLD_YELLOW}📦 Cleaning up disabled feature '$feat'...${RESET}"
                
                # 1. Stop & remove Docker containers
                if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
                    echo "  -> Stopping Docker containers for $feat..."
                    (cd "$app_dir" && sudo docker compose down -v --remove-orphans 2>/dev/null || docker compose down -v 2>/dev/null || true)
                fi
                if [ -n "$containers_running" ]; then
                    docker stop $containers_running 2>/dev/null || true
                    docker rm -f $containers_running 2>/dev/null || true
                fi

                # 2. Archive content & custom files to external drive
                if [ -d "$app_dir" ]; then
                    local archive_target="$ext_drive/disabled/$feat"
                    echo "  -> Archiving files to external drive: $archive_target"
                    if ! sudo mkdir -p "$archive_target" 2>/dev/null; then
                        archive_target="$HOME/.gladstone_disabled_archive/$feat"
                        echo "  -> External mount write-protected. Archiving to: $archive_target"
                        mkdir -p "$archive_target"
                    fi
                    sudo cp -r "$app_dir"/* "$archive_target/" 2>/dev/null || true
                    sudo cp -r "$app_dir"/.* "$archive_target/" 2>/dev/null || true

                    # 3. Remove local workspace directory (sudo required for container data like pgdata)
                    sudo rm -rf "$app_dir"
                    echo -e "${BOLD_GREEN}  ✅ Feature '$feat' removed locally and content transferred to '$archive_target'.${RESET}"
                fi
            fi
        fi
    done
}

list_features() {
    init_config
    echo -e "${BOLD_CYAN}==========================================================${RESET}"
    echo -e "${BOLD_CYAN} 🛠️ GLADSTONE FEATURE CONFIGURATION [Mode: $MODE]${RESET}"
    echo -e "${BOLD_CYAN}==========================================================${RESET}"
    for feat in $(get_mode_features); do
        local label=$(get_feature_label "$feat")
        if is_feature_enabled "$feat"; then
            echo -e "  [${BOLD_GREEN}ENABLED${RESET}]  ${BOLD_CYAN}$feat${RESET} - $label"
        else
            echo -e "  [${BOLD_RED}DISABLED${RESET}] ${feat} - $label"
        fi
    done
    echo -e "${BOLD_CYAN}==========================================================${RESET}"
    echo -e " Config file: $CONFIG_FILE"
    echo -e "${BOLD_CYAN}==========================================================${RESET}"
}

confirm_and_apply_changes() {
    local to_enable=($1)
    local to_disable=($2)

    local msg="Please review and confirm feature changes for [$MODE]:\n\n"
    if [ ${#to_enable[@]} -gt 0 ]; then
        msg+="[TO BE ENABLED]:\n"
        for f in "${to_enable[@]}"; do
            msg+="  • $f ($(get_feature_label "$f"))\n"
        done
        msg+="\n"
    fi

    if [ ${#to_disable[@]} -gt 0 ]; then
        msg+="[TO BE DISABLED & ARCHIVED]:\n"
        for f in "${to_disable[@]}"; do
            msg+="  ⚠️ $f (Containers stopped & files moved to external drive)\n"
        done
        msg+="\n"
    fi

    msg+="Are you sure you want to apply these changes?"

    local confirmed=1

    if command -v whiptail &>/dev/null && [ -t 0 ]; then
        if whiptail --title "Confirm Feature Changes ($MODE)" --yesno "$(echo -e "$msg")" 20 75; then
            confirmed=0
        fi
    else
        echo -e "${BOLD_YELLOW}==========================================================${RESET}"
        echo -e "${BOLD_YELLOW} ⚠️ CONFIRM FEATURE CHANGES [Mode: $MODE]${RESET}"
        echo -e "${BOLD_YELLOW}==========================================================${RESET}"
        echo -e "$msg"
        echo -e "${BOLD_YELLOW}==========================================================${RESET}"
        read -p "Apply changes? (y/N): " choice
        case "$choice" in
            [yY]|[yY][eE][sS]) confirmed=0 ;;
            *) confirmed=1 ;;
        esac
    fi

    if [ $confirmed -eq 0 ]; then
        for f in "${to_enable[@]}"; do
            enable_feature "$f"
        done
        for f in "${to_disable[@]}"; do
            disable_feature "$f"
        done
        echo -e "${BOLD_GREEN}✅ Feature selection saved.${RESET}"
        cleanup_disabled_features
        return 0
    else
        echo -e "${BOLD_YELLOW}❌ Changes cancelled. Feature configuration unchanged.${RESET}"
        return 1
    fi
}

interactive_menu() {
    init_config
    local features=($(get_mode_features))

    if command -v whiptail &>/dev/null && [ -t 0 ]; then
        local w_args=()
        for feat in "${features[@]}"; do
            local label=$(get_feature_label "$feat")
            local status="OFF"
            is_feature_enabled "$feat" && status="ON"
            w_args+=("$feat" "$label" "$status")
        done

        local choices
        choices=$(whiptail --title "Gladstone Feature Manager ($MODE)" \
            --checklist "Select features to enable on this system (Space to toggle, Enter to save):" \
            20 75 10 "${w_args[@]}" 3>&1 1>&2 2>&3)
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            local enable_list=""
            local disable_list=""
            for feat in "${features[@]}"; do
                if echo "$choices" | grep -q "\"$feat\""; then
                    enable_list="$enable_list $feat"
                else
                    disable_list="$disable_list $feat"
                fi
            done

            confirm_and_apply_changes "$enable_list" "$disable_list"
            return 0
        else
            echo -e "${BOLD_YELLOW}❌ Selection cancelled. Feature configuration unchanged.${RESET}"
            return 0
        fi
    fi

    # Terminal Fallback Menu with Draft State
    local temp_state=()
    for feat in "${features[@]}"; do
        if is_feature_enabled "$feat"; then
            temp_state+=(1)
        else
            temp_state+=(0)
        fi
    done

    while true; do
        clear
        echo -e "${BOLD_CYAN}==========================================================${RESET}"
        echo -e "${BOLD_CYAN} 🛠️ GLADSTONE FEATURE MANAGER [Mode: $MODE]${RESET}"
        echo -e "${BOLD_CYAN}==========================================================${RESET}"
        local i=1
        for idx in "${!features[@]}"; do
            local feat="${features[$idx]}"
            local label=$(get_feature_label "$feat")
            if [ "${temp_state[$idx]}" -eq 1 ]; then
                echo -e "  $i) [${BOLD_GREEN}ENABLED${RESET}]  $feat ($label)"
            else
                echo -e "  $i) [${BOLD_RED}DISABLED${RESET}] $feat ($label)"
            fi
            ((i++))
        done
        echo -e "  S) ${BOLD_GREEN}Save & Apply Changes${RESET}"
        echo -e "  Q) Quit without saving"
        echo -e "${BOLD_CYAN}==========================================================${RESET}"
        read -p "Toggle option (1-${#features[@]}), S to save, Q to quit: " choice

        case "$choice" in
            [sS])
                local enable_list=""
                local disable_list=""
                for idx in "${!features[@]}"; do
                    local feat="${features[$idx]}"
                    if [ "${temp_state[$idx]}" -eq 1 ]; then
                        enable_list="$enable_list $feat"
                    else
                        disable_list="$disable_list $feat"
                    fi
                done
                if confirm_and_apply_changes "$enable_list" "$disable_list"; then
                    break
                fi
                ;;
            [qQ])
                echo "Exiting without applying changes."
                break
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#features[@]}" ]; then
                    local idx=$((choice - 1))
                    if [ "${temp_state[$idx]}" -eq 1 ]; then
                        temp_state[$idx]=0
                    else
                        temp_state[$idx]=1
                    fi
                fi
                ;;
        esac
    done
}

# --- CLI ARGUMENT PARSER ---
case "$1" in
    --init)
        init_config
        ;;
    --is-enabled)
        if [ -z "$2" ]; then
            echo "Usage: pi_features.sh --is-enabled <feature_name>"
            exit 1
        fi
        is_feature_enabled "$2"
        exit $?
        ;;
    --enable)
        if [ -z "$2" ]; then
            echo "Usage: pi_features.sh --enable <feature_name>"
            exit 1
        fi
        if [ "$3" != "-y" ] && [ -t 0 ]; then
            read -p "Confirm enabling feature '$2'? (y/N): " conf
            case "$conf" in
                [yY]|[yY][eE][sS]) ;;
                *) echo "Cancelled."; exit 0 ;;
            esac
        fi
        enable_feature "$2"
        cleanup_disabled_features
        ;;
    --disable)
        if [ -z "$2" ]; then
            echo "Usage: pi_features.sh --disable <feature_name>"
            exit 1
        fi
        if [ "$3" != "-y" ] && [ -t 0 ]; then
            echo -e "${BOLD_YELLOW}⚠️ Disabling '$2' will stop its containers and transfer data/config files to external drive.${RESET}"
            read -p "Confirm disabling feature '$2'? (y/N): " conf
            case "$conf" in
                [yY]|[yY][eE][sS]) ;;
                *) echo "Cancelled."; exit 0 ;;
            esac
        fi
        disable_feature "$2"
        cleanup_disabled_features
        ;;
    --cleanup)
        cleanup_disabled_features
        ;;
    --list|--status)
        list_features
        ;;
    --help|-h)
        echo "Gladstone Feature Selector"
        echo "Usage: pi_features.sh [OPTION]"
        echo "  (no args)             Launch interactive selection TUI"
        echo "  --list                List all available features and enabled state"
        echo "  --is-enabled <feat>   Check if feature is enabled (exit code 0 if enabled)"
        echo "  --enable <feat>       Enable a feature"
        echo "  --disable <feat>      Disable a feature"
        echo "  --cleanup             Purge & archive disabled feature containers/files"
        echo "  --init                Initialize configuration file with defaults"
        ;;
    *)
        if [ -n "$1" ]; then
            echo "Unknown option: $1"
            echo "Run 'pi_features.sh --help' for usage."
            exit 1
        fi
        interactive_menu
        ;;
esac
