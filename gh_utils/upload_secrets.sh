#!/bin/bash

# Subcommand to run
COMMAND=$1
# GitHub personal access token
GITHUB_TOKEN=$2
# GitHub repository (format: owner/repo), example: PetScreeningInc/fido-tabby-passport
GITHUB_REPO=$3
shift 3
INPUT_FILES=("$@")

# Create GitHub secrets or variables tied to an environment
create_gh_var_or_secret() {
	local key=$1
	local value=$2
	local env=$3
	local kind=$4

	echo "Setting $kind $key for environment $env"
	if [ "$env" != "all" ]
	then
		if [ "$kind" == "secret" ]
		then
			gh secret set "$key" -b "$value" -R "$GITHUB_REPO" --env "$env" || exit 1
		elif [ "$kind" == "variable" ]
		then
			gh variable set "$key" -b "$value" -R "$GITHUB_REPO" --env "$env" || exit 1
		else
			echo "invalid param to gh"
			exit 1
		fi
	elif [ "$env" == "all" ]
	then
		 if [ "$kind" == "secret" ]
		 then
			 gh secret set "$key" -b "$value" -R "$GITHUB_REPO" || exit 1
		 elif [ "$kind" == "variable" ]
		 then
			 gh variable set "$key" -b "$value" -R "$GITHUB_REPO" || exit 1
		 else
			 echo "invalid param to gh"
			 exit 1
		 fi
	fi
}

# Map long environment names to short ones
map_env_name() {
  case "$1" in
    production) echo "prod" ;;
    *) echo "$1" ;;
  esac
}

env_files_to_json() {
    local json_file="parsed_env_vars.json"
    local temp_file=$(mktemp)

    echo "[]" > "$temp_file"

    for env_file in "${INPUT_FILES[@]}"; do
        env=$(basename "$env_file" | cut -d '.' -f 3)
        short_env=$(map_env_name "$env")

        echo "Processing file: $env_file, derived environment: $short_env"  # Debug output

        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ || ! "$line" == *=* ]] && continue
            key=$(echo "$line" | cut -d '=' -f 1)
            value=$(echo "$line" | cut -d '=' -f 2-)

            json_entry=$(jq -n --arg key "$key" --arg value "$value" --arg env "$short_env" '{
                key: $key,
                value: $value,
                environment_scope: $env,
                masked: false,
                description: ""
            }')
            jq --argjson entry "$json_entry" '. += [$entry]' "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file"
        done < "$env_file"
    done

    mv "$temp_file" "$json_file"
    echo "JSON file generated: $json_file"
}

handle_json_file() {
	local json_file="parsed_env_vars.json"
	jq -c '.[]' "$json_file" | while IFS= read -r var; do
		key=$(echo "$var" | jq -r '.key')
		value=$(echo "$var" | jq -r '.value')
		environment_scope=$(echo "$var" | jq -r '.environment_scope')
		masked=$(echo "$var" | jq -r '.masked')

		if [ "$masked" == "true" ]; then
			kind="secret"
		else
			kind="variable"
		fi

		case "$environment_scope" in
			"develop"|"master"|"mi-prod"|"mi-qa"|"mi-rc"|"mi-uat"|"prod"|"qa"|"rc"|"development")
				create_gh_var_or_secret "$key" "$value" "$environment_scope" "$kind"
				;;
			"all")
				create_gh_var_or_secret "$key" "$value" "all"
			*)
				echo "Unknown environment scope: $environment_scope"
		esac
	done
}

case $COMMAND in
  generate)
    env_files_to_json
    ;;
  upload)
    handle_json_file
    ;;
  *)
    echo "Unknown command: $command"
    echo "Usage:"
    echo "       $0 generate-json <GITHUB_TOKEN> <GITHUB_REPO> <ENV_FILES...>"
    echo "       $0 upload <GITHUB_TOKEN> <GITHUB_REPO>"
    exit 1
    ;;
esac
