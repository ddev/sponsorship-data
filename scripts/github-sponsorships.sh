#!/bin/bash

set -eu -o pipefail

# GitHub API endpoint and token
# GITHUB_TOKEN should be a classic github PAT with "read:org" and "read:user"
# In the context of GitHub Actions, the provided GITHUB_TOKEN should be adequate.
TOKEN="${SPONSORSHIPS_READ_TOKEN}"  # Use GITHUB_TOKEN from the environment
ENTITY="${SPONSORED_ENTITY_NAME}"        # Use ENTITY from SPONSORED_ENTITY_NAME from the environment
ENTITY_TYPE="${SPONSORED_ENTITY_TYPE}" # "org" or "user"
API_URL="https://api.github.com/graphql"
OUTPUT_FILE=data/github-${ENTITY}-sponsorships.jsonc

# Ensure required environment variables are set
if [ -z "${TOKEN:-}" ]; then
    echo "Error: GITHUB_TOKEN is not set."
    exit 1
fi

if [ -z "${ENTITY:-}" ]; then
    echo "Error: ENTITY is not set."
    exit 1
fi

# GraphQL Query
if [ "${ENTITY_TYPE}" = "organization" ]; then
  QUERY=$(cat <<EOF
{
  "query": "query { organization(login: \\"${ENTITY}\\") { sponsorshipsAsMaintainer(first: 100) { totalCount nodes { sponsorEntity { ... on Organization { name } } tier { name monthlyPriceInCents } } } } }"
}
EOF
  )
elif [ "${ENTITY_TYPE}" = "user" ]; then
  QUERY=$(cat <<EOF
{
  "query": "query { user(login: \\"${ENTITY}\\") { sponsorshipsAsMaintainer(first: 100) { totalCount nodes { sponsorEntity { ... on User { name }  } tier { name monthlyPriceInCents } } } } }"
}
EOF
  )
else
  echo "Invalid ENTITY_TYPE specified. Must be 'organization' or 'user'."
  exit 1
fi

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

#echo $RESPONSE | jq

# Parse data with jq
TOTAL_SPONSORS=$(echo "$RESPONSE" | jq ".data.${ENTITY_TYPE}.sponsorshipsAsMaintainer.totalCount")
#TOTAL_MONTHLY=$(echo "$RESPONSE" | jq "[.data.${ENTITY_TYPE}.sponsorshipsAsMaintainer.nodes[].tier.monthlyPriceInCents] | add / 100")
TOTAL_MONTHLY=$(echo "$RESPONSE" | jq "[.data.${ENTITY_TYPE}.sponsorshipsAsMaintainer.nodes[] | select(.tier.name | test(\"a month\")) | .tier.monthlyPriceInCents] | add / 100")
SPONSORS_PER_TIER=$(echo "$RESPONSE" | jq -r "
    .data.${ENTITY_TYPE}.sponsorshipsAsMaintainer.nodes |
    group_by(.tier.name) |
    map({(.[0].tier.name): length}) |
    add
")

# Create JSON result
RESULT=$(jq -n \
    --arg org "${ENTITY}" \
    --arg totalMonthly "$TOTAL_MONTHLY" \
    --argjson totalSponsors "$TOTAL_SPONSORS" \
    --argjson sponsorsPerTier "$SPONSORS_PER_TIER" \
    '{
        ("github_\($org)_sponsorships"): {
            total_monthly_sponsorship: ($totalMonthly | tonumber),
            total_sponsors: $totalSponsors,
            sponsors_per_tier: $sponsorsPerTier
        }
    }'
)
# Output JSON to file
printf "// dynamic github sponsors information, do not edit\n${RESULT}" > ${OUTPUT_FILE}

echo "Sponsorship data saved to '${OUTPUT_FILE}'" >&2
