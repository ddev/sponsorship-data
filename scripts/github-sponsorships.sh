#!/bin/bash

set -eu -o pipefail

# GitHub API endpoint and token
# SPONSORSHIPS_READ_TOKEN should be a classic github PAT with "read:org" and "read:user"
# In the context of GitHub Actions, the provided GITHUB_TOKEN should be adequate.
TOKEN="${SPONSORSHIPS_READ_TOKEN}"
ENTITY="${SPONSORED_ENTITY_NAME}"        # Use ENTITY from SPONSORED_ENTITY_NAME from the environment
ENTITY_TYPE="${SPONSORED_ENTITY_TYPE}" # "organization" or "user"
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

# Prepare GraphQL query template with cursor
QUERY_TEMPLATE='query($entity: String!, $after: String) {
  %s(login: $entity) {
    sponsorshipsAsMaintainer(first: 100, after: $after, includePrivate: true) {
      totalCount
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        sponsorEntity {
          ... on Organization { name }
          ... on User { login }
        }
        tier {
          name
          monthlyPriceInCents
        }
        privacyLevel
      }
    }
  }
}'

if [ "${ENTITY_TYPE}" = "organization" ]; then
  GH_TYPE="organization"
elif [ "${ENTITY_TYPE}" = "user" ]; then
  GH_TYPE="user"
else
  echo "Invalid ENTITY_TYPE specified. Must be 'organization' or 'user'."
  exit 1
fi

# Pagination loop to collect all sponsorships
AFTER=null
ALL_NODES="[]"
HAS_NEXT_PAGE=true
TOTAL_COUNT=0

while [ "$HAS_NEXT_PAGE" = true ]; do
  # Prepare the query for this page
  QUERY=$(jq -n \
    --arg entity "$ENTITY" \
    --arg after "$([ "$AFTER" = null ] && echo null || echo "\"$AFTER\"")" \
    --arg query "$(printf "$QUERY_TEMPLATE" "$GH_TYPE")" \
    '{
      query: $query,
      variables: {
        entity: $entity,
        after: ($after | fromjson)
      }
    }'
  )

  RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
                   -H "Content-Type: application/json" \
                   -d "$QUERY" \
                   $API_URL)

  if [ $? -ne 0 ] || echo "$RESPONSE" | jq -e '.errors' >/dev/null 2>&1; then
      echo "Error fetching data from GitHub API:"
      echo "$RESPONSE" | jq '.errors'
      exit 1
  fi

  # Save totalCount from the first page
  if [ "$TOTAL_COUNT" -eq 0 ]; then
    TOTAL_COUNT=$(echo "$RESPONSE" | jq ".data.${ENTITY_TYPE}.sponsorshipsAsMaintainer.totalCount")
  fi

  # Extract nodes and append to ALL_NODES
  PAGE_NODES=$(echo "$RESPONSE" | jq ".data.${ENTITY_TYPE}.sponsorshipsAsMaintainer.nodes")
  ALL_NODES=$(jq -s 'add' <(echo "$ALL_NODES") <(echo "$PAGE_NODES"))

  # Check for next page
  HAS_NEXT_PAGE=$(echo "$RESPONSE" | jq ".data.${ENTITY_TYPE}.sponsorshipsAsMaintainer.pageInfo.hasNextPage")
  AFTER=$(echo "$RESPONSE" | jq -r ".data.${ENTITY_TYPE}.sponsorshipsAsMaintainer.pageInfo.endCursor")
  if [ "$AFTER" = "null" ]; then
    AFTER=null
  fi
done

# Save all nodes to a temp file for further processing
echo "$ALL_NODES" > /tmp/all_sponsorship_nodes.json

TOTAL_MONTHLY_SPONSORSHIPS=$(jq "[.[] | select(.tier.name | test(\"a month\")) | .tier.monthlyPriceInCents] | add / 100" /tmp/all_sponsorship_nodes.json)
SPONSORS_PER_TIER=$(jq -r "
    . |
    map(select(.tier.name)) |
    group_by(.tier.name) |
    map({(.[0].tier.name): length}) |
    add
" /tmp/all_sponsorship_nodes.json)

# Create JSON result
RESULT=$(jq -n \
    --arg org "${ENTITY}" \
    --arg totalMonthly "$TOTAL_MONTHLY_SPONSORSHIPS" \
    --argjson totalSponsors "$TOTAL_COUNT" \
    --argjson sponsorsPerTier "$SPONSORS_PER_TIER" \
    '{
        ("github_\($org)_sponsorships"): {
            total_monthly_sponsorship: ($totalMonthly | tonumber),
            total_sponsors: $totalSponsors,
            sponsors_per_tier: (
                $sponsorsPerTier |
                to_entries |
                map({key: .key, value: .value, num: (.key | capture("\\$(?<amount>\\d+) ") | .amount | tonumber)}) |
                sort_by(.num) |
                map({(.key): .value}) |
                add
            )
        }
    }'
)

# Output JSON to file
printf "// dynamic github sponsors information, do not edit\n${RESULT}" > ${OUTPUT_FILE}

echo "Sponsorship data saved to '${OUTPUT_FILE}'" >&2
