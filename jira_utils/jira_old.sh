#!/bin/bash

##
# few more things to fixup like passing the current release branch version
#
# example using old release candidates
ISSUES=(
"https://petscreening.atlassian.net/browse/LTR-1405"
"https://petscreening.atlassian.net/browse/LTR-1289"
"https://petscreening.atlassian.net/browse/LTR-1348"
"https://petscreening.atlassian.net/browse/LTR-1283"
"https://petscreening.atlassian.net/browse/LTR-1389"
"https://petscreening.atlassian.net/browse/LTR-1385"
)

# Export a jira token from
# https://id.atlassian.com/manage-profile/security/api-tokens
# Dont forget to update JIRA_USERNAME too
JIRA_API_TOKEN="${JIRA_API_TOKEN}"
JIRA_BASE_URL="https://petscreening.atlassian.net"
JIRA_USERNAME="bret.horne@petscreening.com"

jira::issue_key() {
	echo "$1" | awk -F'/' '{print $NF}'
}

jira::issue_info() {
	local issue_key="$1"
	curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
		-H "Content-Type: application/json" \
		"$JIRA_BASE_URL/rest/api/2/issue/$issue_key"
	}

jira::vc_info() {
	local issue_id="$1"
	curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
		-H "Content-Type: application/json" \
		"$JIRA_BASE_URL/rest/dev-status/1.0/issue/details?issueId=$issue_id&applicationType=gitlab&dataType=pullrequest"
	}

jira::update_log() {
	local version="$1"

	local changes=""
	for issue_url in "${ISSUES[@]}"; do
		key=$(jira::issue_key "$issue_url")
		info=$(jira::issue_info "$key")
		id=$(printf '%s\n' "$info" | jq -r '.id')
		title=$(printf '%s\n' "$info" | jq -r '.fields.summary // "N/A"')

		change_entry=$(printf '%s [%s](%s)' "- $title" "$key" "$issue_url")
		changes="$changes$change_entry\n"
	done

	date_today=$(date +'%Y-%m-%d')
	#FIXME with actual handling of versions
	version="vX.X.X"
	changelog_entry="## $version ($date_today)\n\n$changes"

	echo -e "3 insert\n$changelog_entry\n.\nx" | ex -s CHANGELOG.md
}

jira::print_all() {
	for issue_url in "${ISSUES[@]}"; do
		key=$(jira::issue_key "$issue_url")
		info=$(jira::issue_info "$key")
		id=$(printf '%s\n' "$info" | jq -r '.id')
		vc_info=$(jira::vc_info "$id")
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


#source me
#and call: jira::update_log
jira::update_log
#or jira::print_all
