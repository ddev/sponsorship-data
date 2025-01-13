#!/bin/bash

set -eu -o pipefail

# GitHub API endpoint and token
# GITHUB_TOKEN should be a classic github PAT with "read:org" and "read:user"
# In the context of GitHub Actions, the provided GITHUB_TOKEN should be adequate.
TOKEN="${SPONSORSHIPS_READ_TOKEN}"  # Use GITHUB_TOKEN from the environment
ORG="${SPONSORED_ORG_NAME}"        # Use ORG_NAME from the environment
API_URL="https://api.github.com/graphql"
OUTPUT_FILE=data/github-sponsorships.jsonc

# Ensure required environment variables are set
if [ -z "${TOKEN:-}" ]; then
    echo "Error: GITHUB_TOKEN is not set."
    exit 1
fi

if [ -z "${ORG:-}" ]; then
    echo "Error: ORG is not set."
    exit 1
fi

# GraphQL Query
QUERY=$(cat <<EOF
{
  "query": "query { organization(login: \\"${ORG}\\") { sponsorshipsAsMaintainer(first: 100) { totalCount nodes { sponsorEntity { ... on User { name } ... on Organization { name } } tier { name monthlyPriceInCents } } } } }"
}
EOF
)

# Fetch data from GitHub API
RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
                     -H "Content-Type: application/json" \
                     -d "$QUERY" \
                     $API_URL)

# Check for errors in the API response
if [ $? -ne 0 ] || echo "$RESPONSE" | jq -e '.errors' >/dev/null 2>&1; then
    echo "Error fetching data from GitHub API:"
    echo "$RESPONSE" | jq '.errors'
    exit 1
fi

# Parse data with jq
TOTAL_SPONSORS=$(echo "$RESPONSE" | jq '.data.organization.sponsorshipsAsMaintainer.totalCount')
TOTAL_MONTHLY=$(echo "$RESPONSE" | jq '[.data.organization.sponsorshipsAsMaintainer.nodes[].tier.monthlyPriceInCents] | add / 100')
SPONSORS_PER_TIER=$(echo "$RESPONSE" | jq -r '
    .data.organization.sponsorshipsAsMaintainer.nodes |
    group_by(.tier.name) |
    map({(.[0].tier.name): length}) |
    add
')

# Create JSON result
RESULT=$(jq -n \
    --arg totalMonthly "$TOTAL_MONTHLY" \
    --argjson totalSponsors "$TOTAL_SPONSORS" \
    --argjson sponsorsPerTier "$SPONSORS_PER_TIER" \
    --arg updateDatetime "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    '{
        total_monthly_sponsorship: ($totalMonthly | tonumber),
        total_sponsors: $totalSponsors,
        sponsors_per_tier: $sponsorsPerTier,
        update_datetime: $updateDatetime
    }'
)

# Output JSON to file
echo "$RESULT" > ${OUTPUT_FILE}

echo "Sponsorship data saved to '${OUTPUT_FILE}'" >&2
