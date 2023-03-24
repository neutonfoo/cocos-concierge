#!/bin/bash

set -ex

app_name=$1
app_repository=$2
app_branch=$3

# Verify that remote branch exists
remote_branch_exists=$(git ls-remote --heads "git@github.com:$app_repository.git" $app_branch | wc -l)

if [[ $remote_branch_exists -eq "0" ]]; then
    echo "Remote branch \`$app_branch\` does not exist"
    echo "Deployment script terminating"
    exit 1
fi

# Continue with deployment
 
cd ../../

if [[ -d $app_name ]]; then
    docker compose -f "$app_name/docker-compose.yml" down
    rm -rf $app_name
fi

git clone --depth 1 --branch $app_branch "git@github.com:$app_repository.git" "$app_name"
docker compose -f "$app_name/docker-compose.yml" up -d --build

exit 0