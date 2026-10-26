#!/usr/bin/env bash
# Creates a docker-compose.yml (and a systemd service) for synchronist in the current directory.
# Use --offline to use the files next to this script instead of downloading them and to load the
# docker images (*.tar) in the current directory.

set -euo pipefail

offline=false
if [ "${1:-}" = "--offline" ]; then
    offline=true
fi
repository=https://raw.githubusercontent.com/aimaard/synchronist/main

fetch() {
    if $offline; then
        cat "$(dirname "$0")/$1"
    else
        curl --silent --fail "$repository/$1"
    fi
}

compose=$(fetch docker-compose.sample.yml | grep -v '^# Template')

read -p "Mode (sender/receiver) [receiver]: " mode
mode=${mode:-receiver}
if [ "$mode" != "sender" ] && [ "$mode" != "receiver" ]; then
    echo "Mode must be sender or receiver" >&2
    exit 1
fi

read -p "Web interface username [synchronist]: " username
username=${username:-synchronist}

pw=$(openssl rand -hex 12)
read -p "Web interface password [$pw]: " password
password=${password:-$pw}

read -p "Port for web interface [80]: " port
port=${port:-80}

volumes=()
environment=()
volume() {
    local host_folder
    read -p "$1: " host_folder
    if [ -z "$host_folder" ]; then
        echo "A folder is required" >&2
        exit 1
    fi
    volumes+=("      - $host_folder:$2")
}

if [ "$mode" = "receiver" ]; then
    volume "Storage folder holding the mirrored files" /data/storage
    volume "Receive folder the files from the sender arrive in" /data/receive
    volume "Folder to put the payload for the sender into" /data/payload

    read -p "Relay folder to also copy all received files into (leave empty to disable): " relay_folder
    if [ -n "$relay_folder" ]; then
        volumes+=("      - $relay_folder:/data/relay")
        environment+=("      SYNCHRONIST_RELAY_FOLDER: /data/relay")
    fi

    read -p "How often to send a payload to the sender (cron) [0 */6 * * *]: " sync_cron
    environment+=("      SYNCHRONIST_SYNC_CRON: \"${sync_cron:-0 */6 * * *}\"")
else
    volume "Source folder to mirror" /data/source
    volume "Send folder to put the missing/changed files into" /data/send
    volume "Folder the payload from the receiver arrives in" /data/payload
fi

read -p "Is the incoming folder a network share (SMB/NFS) mounted on this machine? [y/N]: " network_share
if [ "${network_share:-n}" = "y" ]; then
    environment+=("      SYNCHRONIST_WATCHER_POLLING: \"true\"")
fi

compose=${compose//"<mode>"/"$mode"}
compose=${compose//"<username>"/"$username"}
compose=${compose//"<password>"/"$password"}
compose=${compose//"<port>"/"$port"}
compose=${compose//"<volumes>"/"$(IFS=$'\n'; echo "${volumes[*]}")"}
compose=${compose//$'<environment>\n'/"$(IFS=$'\n'; echo "${environment[*]}")"$'\n'}
compose=${compose//$'\n\n    volumes:'/$'\n    volumes:'}

cat <<< "$compose" > "./docker-compose.yml"
echo "Created docker-compose.yml"

if [ -d "/usr/lib/systemd/system" ]; then
    echo "Installing service file..."
    service=$(fetch synchronist.service)

    read -p "Systemd service user [root]: " service_user
    service_user=${service_user:-root}

    service=${service//"<service_user>"/"$service_user"}
    service=${service//"<working_directory>"/"$PWD"}

    sudo tee "/usr/lib/systemd/system/synchronist.service" <<< "$service" > /dev/null
else
    echo "No systemd found, use: docker compose up -d"
fi

if $offline; then
    echo "Loading all docker images into the local docker registry..."
    for tarfile in *.tar; do
        [ -e "$tarfile" ] || continue
        docker load -i "$tarfile"
    done
fi

echo "Web interface: http://localhost:$port (user: $username, password: $password)"
