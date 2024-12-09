#!/opt/homebrew/bin/bash

##
# few more things to fixup like passing the current release branch version
#
# example using release candidates
#ISSUES=(
#"https://petscreening.atlassian.net/browse/LTR-1125"
#"https://petscreening.atlassian.net/browse/LTR-1375"
#"https://petscreening.atlassian.net/browse/LTR-1359"
#"https://petscreening.atlassian.net/browse/LTR-1384"
#"https://petscreening.atlassian.net/browse/LTR-1303"
#"https://petscreening.atlassian.net/browse/LTR-1125"
#"https://petscreening.atlassian.net/browse/PI-524"
#"https://petscreening.atlassian.net/browse/PI-359"
#)

# Export a jira token from
# https://id.atlassian.com/manage-profile/security/api-tokens
# Dont forget to update JIRA_USERNAME too
if [ -z "$JIRA_API_TOKEN" ] && [ -z "$JIRA_USERNAME" ]
then
	echo "No values supplied for JIRA_API_TOKEN & JIRA_USERNAME"
	exit 1
fi

JIRA_API_TOKEN="$JIRA_API_TOKEN"
JIRA_BASE_URL="https://petscreening.atlassian.net"
#JIRA_USERNAME="bret.horne@petscreening.com"

issue_key() {
    echo "$1" | awk -F'/' '{print $NF}'
}

issue_info() {
    local issue_key="$1"
    curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
         -H "Content-Type: application/json" \
         "$JIRA_BASE_URL/rest/api/2/issue/$issue_key"
}

vc_info() {
    local issue_id="$1"
    curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
         -H "Content-Type: application/json" \
         "$JIRA_BASE_URL/rest/dev-status/1.0/issue/details?issueId=$issue_id&applicationType=gitlab&dataType=pullrequest"
}

update_log() {
    local version="$1"
	local changelogPath="$2"
	local issuesFile="$3"
    local changes=""

	readarray -t issues < $issuesFile

    for issue_url in "${issues[@]}"; do
        key=$(issue_key "$issue_url")
        info=$(issue_info "$key")
        id=$(printf '%s\n' "$info" | jq -r '.id')
        title=$(printf '%s\n' "$info" | jq -r '.fields.summary // "N/A"')

        change_entry=$(printf '%s [%s](%s)' "- $title" "$key" "$issue_url")
        changes="$changes$change_entry\n"
    done

    date_today=$(date +'%Y-%m-%d')
    changelog_entry="## $version ($date_today)\n\n$changes"

    echo -e "3 insert\n$changelog_entry\n.\nx" | ex -s $changelogPath
}

print_changes() {
	local issues="$1"
    for issue_url in "${issues[@]}"; do
        key=$(issue_key "$issue_url")
        info=$(issue_info "$key")
        id=$(printf '%s\n' "$info" | jq -r '.id')
        vc_info=$(vc_info "$id")
        title=$(printf '%s\n' "$info" | jq -r '.fields.summary // "N/A"')
        pull_req_url=$(printf '%s\n' "$vc_info" | jq -r '.detail[]?.pullRequests[]? | "\(.name) (\(.status)) - \(.url)"')
        branches=$(printf '%s\n' "$vc_info" | jq -r '.detail[]?.branches[]? | "\(.name)"')
        commits=$(printf '%s\n' "$vc_info" | jq -r '.detail[]?.commits[]? | "\(.displayId) - \(.author.name): \(.message)"')

        echo "Issue: $key"
        echo "Title: $title"
        echo "Branches: $branches"
        echo "Commits: $commits"
        echo "Pull Requests: $pull_req_url"
        echo "-----------------------"
    done
}

update_log
