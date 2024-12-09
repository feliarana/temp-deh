#!/bin/bash

# GitHub personal access token
GITHUB_TOKEN=$1
# GitHub repository (format: owner/repo)
GITHUB_REPO=$2
# Our github Org
OWNER="PetScreeningInc"

# Function to create GitHub environment
create_github_environment() {
 local env=$1
 echo "Creating environment $env if it does not exist"
 curl -X PUT -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$OWNER/$GITHUB_REPO/environments/$env"
}

# Environments to create
ENVIRONMENTS=("development" "develop" "master" "mi-prod" "mi-qa" "mi-rc" "mi-uat" "prod" "qa" "rc" "default")

for ENV in "${ENVIRONMENTS[@]}"; do
 create_github_environment "$ENV"
done
