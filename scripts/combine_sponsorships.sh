#!/bin/bash

set -eu -o pipefail

if ! command -v strip-json-comments >/dev/null; then
  echo "strip-json-comments-cli is required, 'sudo npm install -g strip-json-comments-cli'" && exit 1
fi

# Input files
inputs="github-sponsorships invoiced-sponsorships paypal-sponsorships"

# Output file
output_file="all-sponsorships.json"

mkdir -p data/tmp

for f in ${inputs}; do
  strip-json-comments data/$f.jsonc > data/tmp/$f.json
done
#
## Combine the files into one
#jq -s '{
#  "github_sponsorships": .[0],
#  "invoiced_sponsorships": .[1],
#  "paypal_sponsorships": .[2]
#}' "$file1" "$file2" "$file3" > "$output_file"
#
#echo "Combined JSONC written to $output_file" >&2
