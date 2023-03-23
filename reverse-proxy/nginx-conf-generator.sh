#!/bin/bash

# IMPORTANT
# This file is run from the main reposity directory (not this one)
# -- ALl URLs are relative to the repository directory (parent of this folder)

PARENT_DIR="reverse-proxy"

# Services config is a string array that contains the nginx.conf locations for services
declare -a services_config=()

# Load project.json into a variable
PROJECTS_JSON=$(cat "projects.json")

# Collect the keys and load the services/daemon jsons themselves
SERVICES_JSON=$(echo $PROJECTS_JSON | jq -r '.services')
SERVICES=$(echo $PROJECTS_JSON | jq -r '.services|keys[]')

DAEMONS_JSON=$(echo $PROJECTS_JSON | jq -r '.daemons')
DAEMONS=$(echo $PROJECTS_JSON | jq -r '.daemons|keys[]')

# Loop through services
for service_name in $SERVICES; do
	repository=$(echo $SERVICES_JSON | jq -r ".$service_name")

	# Replace the / with an underscore
	repo_folder_name=$(echo $repository | sed -r 's/\//_/g')

	if [ ! -d ../"$repo_folder_name" ]; then
		git clone --depth 1 --branch main git@github.com:$repository.git ../"$repo_folder_name"
	fi

	# Since it's a service, add to nginx.conf to enable routing
	services_config+=(
		"location ~ ^\/$service_name\/(.*)$
		{
			set \$target http://$service_name;
			rewrite ^\/$service_name\/(.*)$ /\$2 break;
			proxy_pass \$target;
		}"
	)
done

for daemon_name in $DAEMONS; do
	repository=$(echo $DAEMONS_JSON | jq -r ".$daemon_name")
	echo $repository
done

cat << EOF > ./"$PARENT_DIR"/nginx.conf
worker_processes 1;

events
{
	worker_connections 1024;
}

http
{
	server
	{
		listen 80;
		listen [::]:80;
		server_name localhost;

        proxy_buffering off;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
		
		resolver 127.0.0.11 valid=30s;

		location ~ ^\/updater\/(.*)$
		{
			set \$target http://updater;
			rewrite ^\/updater\/(.*)$ /\$2 break;
			proxy_pass \$target;
		}

		${services_config[@]}
	}
}
EOF