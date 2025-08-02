#!/bin/bash

set -eu -o pipefail

if ! command -v strip-json-comments >/dev/null; then
  echo "strip-json-comments-cli is required, 'sudo npm install -g strip-json-comments-cli'" && exit 1
fi

# Input files
inputs="github-ddev-sponsorships github-rfay-sponsorships invoiced-sponsorships paypal-sponsorships goals"

# Output file
output_file="data/all-sponsorships.json"

mkdir -p data/tmp

for f in ${inputs}; do
  strip-json-comments data/$f.jsonc > data/tmp/$f.json
done

github_ddev_total_monthly=$(jq -r .github_ddev_sponsorships.total_monthly_sponsorship data/tmp/github-ddev-sponsorships.json)
github_rfay_total_monthly=$(jq -r .github_rfay_sponsorships.total_monthly_sponsorship data/tmp/github-rfay-sponsorships.json)
invoiced_total_monthly=$(jq -r .monthly_invoiced_sponsorships.total_monthly_sponsorship data/tmp/invoiced-sponsorships.json)
invoiced_annual_monthly_equivalent=$(jq -r .annual_invoiced_sponsorships.monthly_equivalent_sponsorship data/tmp/invoiced-sponsorships.json)
paypal_total_monthly=$(jq -r .paypal_sponsorships data/tmp/paypal-sponsorships.json)
total_monthly_average_income=$((github_ddev_total_monthly + github_rfay_total_monthly + invoiced_total_monthly + invoiced_annual_monthly_equivalent + paypal_total_monthly))

# Get historical data from git (find commits from before specific time periods)
one_week_ago=$(git log --format="%H" --before="1 week ago" -1 2>/dev/null || echo "")
one_month_ago=$(git log --format="%H" --before="1 month ago" -1 2>/dev/null || echo "")
one_year_ago=$(git log --format="%H" --before="1 year ago" -1 2>/dev/null || echo "")

# Extract historical total_monthly_average_income if commits exist
historical_1w=""
historical_1m=""
historical_1y=""

if [ -n "$one_week_ago" ]; then
  historical_1w=$(git show "$one_week_ago:data/all-sponsorships.json" 2>/dev/null | jq -r '.total_monthly_average_income // empty' 2>/dev/null || echo "")
fi

if [ -n "$one_month_ago" ]; then
  historical_1m=$(git show "$one_month_ago:data/all-sponsorships.json" 2>/dev/null | jq -r '.total_monthly_average_income // empty' 2>/dev/null || echo "")
fi

if [ -n "$one_year_ago" ]; then
  historical_1y=$(git show "$one_year_ago:data/all-sponsorships.json" 2>/dev/null | jq -r '.total_monthly_average_income // empty' 2>/dev/null || echo "")
fi

# Calculate goal progress percentage
goal_target=$(jq -r .current_goal.target_amount data/tmp/goals.json)
if [ "$goal_target" != "null" ] && [ "$goal_target" -gt 0 ]; then
  goal_progress=$(echo "scale=2; $total_monthly_average_income * 100 / $goal_target" | bc)
else
  goal_progress=0
fi

# Extract appreciation message
appreciation_message=$(jq -r .appreciation_message data/tmp/goals.json)

# Build git-based historical data JSON
git_historical_data="{}"
if [ -n "$historical_1w" ]; then
  git_historical_data=$(echo "$git_historical_data" | jq --argjson val "$historical_1w" '. + {"one_week_ago": $val}')
fi
if [ -n "$historical_1m" ]; then
  git_historical_data=$(echo "$git_historical_data" | jq --argjson val "$historical_1m" '. + {"one_month_ago": $val}')
fi
if [ -n "$historical_1y" ]; then
  git_historical_data=$(echo "$git_historical_data" | jq --argjson val "$historical_1y" '. + {"one_year_ago": $val}')
fi

# Monthly historical tracking - capture snapshot when month changes
current_month=$(date -u +'%Y-%m')
current_date=$(date -u +'%Y-%m-%d')

# Get existing monthly historical data or initialize empty
monthly_historical_data="{}"
if [ -f "$output_file" ]; then
  monthly_historical_data=$(jq -r '.monthly_historical_data // {}' "$output_file" 2>/dev/null || echo "{}")
fi

# Check if we need to capture this month's data
needs_monthly_capture=false
if [ "$monthly_historical_data" = "{}" ]; then
  # First time - capture current month
  needs_monthly_capture=true
else
  # Check if current month is already captured
  current_month_exists=$(echo "$monthly_historical_data" | jq -r "has(\"$current_month\")")
  if [ "$current_month_exists" = "false" ]; then
    needs_monthly_capture=true
  fi
fi

# Capture monthly snapshot if needed
if [ "$needs_monthly_capture" = "true" ]; then
  monthly_historical_data=$(echo "$monthly_historical_data" | jq \
    --arg month "$current_month" \
    --arg date "$current_date" \
    --argjson amount "$total_monthly_average_income" \
    '. + {($month): {"date": $date, "total_monthly_average_income": $amount}}')
fi

## Combine the files into one and add update time.
jq -s --arg updated_datetime "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --argjson total_monthly_average_income ${total_monthly_average_income} \
  --argjson goal_progress ${goal_progress} \
  --argjson git_historical_data "$git_historical_data" \
  --argjson monthly_historical_data "$monthly_historical_data" \
  --arg appreciation_message "$appreciation_message" \
  'reduce .[] as $item ({}; . * $item) | .current_goal.progress_percentage = $goal_progress | . + {total_monthly_average_income: $total_monthly_average_income} + {updated_datetime: $updated_datetime} + {historical_data: $git_historical_data} + {monthly_historical_data: $monthly_historical_data} + {appreciation_message: $appreciation_message}' \
  data/tmp/*.json > "${output_file}"

echo "Combined JSONC written to $output_file" >&2
