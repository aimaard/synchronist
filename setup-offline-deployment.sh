#!/usr/bin/env bash

set -euo pipefail

compose=$(cat docker-compose.sample.yml)

secret_key=$(openssl rand -base64 36)
pw=$(openssl rand -hex 12)

read -p "Web interface username [synchronist]: " username
username=${username:-synchronist}

read -p "Web interface password: " password
password=${password:-$pw}

read -p "Port for web interface [80]: " port
port=${port:-80}

read -p "Docker volumes (comma-separated, e.g. /host:/container,/data:/data): " volumes_in
IFS=', ' read -r -a volumes_arr <<< "$volumes_in"

volumes_yml=()
for element in ${volumes_arr[@]}
do
    volumes_yml+=("      - $element")
done
volumes=$(IFS=$'\n'; echo "${volumes_yml[*]}")


compose=${compose//"<secret_key>"/"$secret_key"}
compose=${compose//"<username>"/"$username"}
compose=${compose//"<password>"/"$password"}
compose=${compose//"<port>"/"$port"}
compose=${compose//"<volumes>"/"$volumes"}

cat <<< "$compose" > "./docker-compose.yml"


if [ -d "/usr/lib/systemd/system" ]; then
    echo "Installing service file..."
    service=$(cat synchronist.service)

    read -p "Systemd service user [root]: " service_user
    service_user=${service_user:-root}

    service=${service//"<service_user>"/"$service_user"}
    service=${service//"<working_directory>"/"$PWD"}

    sudo cat <<< "$service" > "/usr/lib/systemd/system/synchronist.service"
else
    echo "No systemd found, use: docker compose up -d"
fi

echo "Loading all docker containers into local docker registry.. "
for tarfile in *.tar; do
    docker load -i "$tarfile"
done
