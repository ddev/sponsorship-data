#!/bin/bash

set -eu -o pipefail

if ! command -v strip-json-comments >/dev/null; then
  echo "strip-json-comments-cli is required, 'sudo npm install -g strip-json-comments-cli'" && exit 1
fi

# Input files
inputs="github-sponsorships invoiced-sponsorships paypal-sponsorships"

# Output file
output_file="data/all-sponsorships.json"

mkdir -p data/tmp

for f in ${inputs}; do
  strip-json-comments data/$f.jsonc > data/tmp/$f.json
done

github_total_monthly=$(jq -r .github_sponsorships.total_monthly_sponsorship data/tmp/github-sponsorships.json)
invoiced_total_monthly=$(jq -r .monthly_invoiced_sponsorships.total_monthly_sponsorship data/tmp/invoiced-sponsorships.json)
invoiced_monthly_annual_equivalent=$(jq -r .annual_invoiced_sponsorships.monthly_equivalent_sponsorship data/tmp/invoiced-sponsorships.json)
paypal_total_monthly=$(jq -r .paypal_sponsorships data/tmp/paypal-sponsorships.json)


## Combine the files into one and add update time.
jq -s --arg updated_datetime "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  'reduce .[] as $item ({}; . * $item) + {updated_datetime: $updated_datetime}' \
  data/tmp/*.json > "${output_file}"

echo "Combined JSONC written to $output_file" >&2
