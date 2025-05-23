#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

log() {
    echo "$1" >&2
}

# --- Input Validation & Setup ---

# Check if GH_REPO is set (needed for gh cli).
GH_REPO=$1
if [ -z "$GH_REPO" ]; then
  log "Error: Repository must be provided as the first argument."
  log "Usage: ./translate.sh owner/repo <issue_number>"
  exit 1
fi

# Check if an Issue Number was provided.
ISSUE_NUMBER=$2
if [ -z "$ISSUE_NUMBER" ]; then
  log "Error: Issue number must be provided as the second argument."
  log "Usage: ./translate.sh owner/repo <issue_number>"
  exit 1
fi

# Check if GEMINI_API_KEY is set.
if [ -z "$GEMINI_API_KEY" ]; then
  log "Error: GEMINI_API_KEY environment variable is not set."
  exit 1
fi

# Check if gh command exists.
if ! command -v gh &> /dev/null; then
    log "Error: 'gh' (GitHub CLI) command not found. Please install it."
    exit 1
fi

# Check if jq command exists.
if ! command -v jq &> /dev/null; then
    log "Error: 'jq' command not found. Please install it."
    exit 1
fi

# Check if GH_TOKEN is set (needed for gh cli auth in non-interactive/CI).
# If running locally, 'gh' might use your logged-in session.
GH_TOKEN="${GH_TOKEN:-}"
GITHUB_ACTIONS="${GITHUB_ACTIONS:-false}"
if [ -z "${GH_TOKEN}" ] && [ "${GITHUB_ACTIONS}" == "true" ]; then
    log "Error: GH_TOKEN environment variable must be set when running in GitHub Actions."
    exit 1
fi

log "Fetching issue $ISSUE_NUMBER from $GH_REPO..."

# --- Fetch Issue Details using GitHub CLI ---

# Fetch the issue title and body using 'gh issue view' and parse with jq.
# We set GH_TOKEN explicitly if provided, otherwise gh tries existing auth.
ISSUE_DATA=$(GH_TOKEN=${GH_TOKEN} gh issue view "$ISSUE_NUMBER" --json title,body --repo "$GH_REPO")

# Extract title and body.
ISSUE_TITLE=$(echo "$ISSUE_DATA" | jq -r '.title')
ISSUE_BODY=$(echo "$ISSUE_DATA" | jq -r '.body')

# Check if fetching was successful / content is not empty.
if [ -z "$ISSUE_TITLE" ] && [ -z "$ISSUE_BODY" ]; then
    log "Error: Could not fetch title or body for issue $ISSUE_NUMBER. Check the issue number and repository."
    exit 1
fi

log "Issue Title: $ISSUE_TITLE"
log "---"

# --- Gemini API Call ---

log "Calling Gemini API for translation..."

# Prepare the prompt for Gemini.
PROMPT="Translate the following GitHub issue title and body to English *only if* the primary language is Chinese. If it is not Chinese, respond *exactly* with 'NO_TRANSLATION_NEEDED'.\n\nTitle: $ISSUE_TITLE\n\nBody: $ISSUE_BODY"

# Prepare the JSON payload.
JSON_PAYLOAD=$(jq -n --arg prompt "$PROMPT" \
  '{ "contents":[ { "parts":[ { "text": $prompt } ] } ] }')

# Define the Gemini API endpoint.
API_URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent?key=${GEMINI_API_KEY}"

# Call the Gemini API.
API_RESPONSE=$(curl -s -H 'Content-Type: application/json' -X POST "$API_URL" -d "$JSON_PAYLOAD")

# --- Process Response ---

# Check for API errors.
if echo "$API_RESPONSE" | jq -e '.error' > /dev/null; then
  ERROR_MSG=$(echo "$API_RESPONSE" | jq -r '.error.message // "Unknown API error"')
  log "Error: API call failed - $ERROR_MSG"
  exit 1
fi

# Extract the translated text.
TRANSLATED_TEXT=$(echo "$API_RESPONSE" | jq -r '.candidates[0].content.parts[0].text // "Error: Could not parse response"')

echo "$TRANSLATED_TEXT"
