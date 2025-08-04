#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the repository root directory:
#   bats ./tests/test.bats
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export TESTDIR=$(mktemp -d)
  
  # Copy repository to test directory to avoid modifying original
  cp -r "${DIR}"/* "${TESTDIR}"/
  cd "${TESTDIR}"
  
  # Ensure required tools are available
  if ! command -v jq >/dev/null; then
    skip "jq is required but not installed"
  fi
  if ! command -v strip-json-comments >/dev/null; then
    skip "strip-json-comments-cli is required but not installed"
  fi
  if ! command -v bc >/dev/null; then
    skip "bc is required but not installed"
  fi

}

teardown() {
  set -eu -o pipefail
  [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
}

@test "all required input files exist" {
  assert_file_exists "data/github-ddev-sponsorships.jsonc"
  assert_file_exists "data/github-rfay-sponsorships.jsonc"
  assert_file_exists "data/invoiced-sponsorships.jsonc"
  assert_file_exists "data/paypal-sponsorships.jsonc"
  assert_file_exists "data/goals.jsonc"
  assert_file_exists "scripts/combine-sponsorships.sh"
  assert_file_exists "scripts/github-sponsorships.sh"
}

@test "input JSONC files have valid JSON structure" {
  for file in data/*.jsonc; do
    echo "# Validating ${file}" >&3
    run strip-json-comments "${file}"
    assert_success
    run bash -c "strip-json-comments '${file}' | jq ."
    assert_success
  done
}

@test "goals.jsonc has required structure" {
  run bash -c "strip-json-comments data/goals.jsonc | jq -e '.current_goal.target_amount > 0'"
  assert_success
  
  run bash -c "strip-json-comments data/goals.jsonc | jq -e '.sponsorship_goals | length > 0'"
  assert_success
  
  run bash -c "strip-json-comments data/goals.jsonc | jq -e '.sponsorship_goals[0] | has(\"goal_id\") and has(\"target_amount\") and has(\"goal_creation_date\")'"
  assert_success
}

@test "combine-sponsorships.sh produces valid output" {
  run bash scripts/combine-sponsorships.sh
  assert_success
  assert_output --partial "Combined JSONC written to data/all-sponsorships.json"
  
  # Verify output file exists and is valid JSON
  assert_file_exists "data/all-sponsorships.json"
  run jq . data/all-sponsorships.json
  assert_success
}

@test "all-sponsorships.json has required fields" {
  run bash scripts/combine-sponsorships.sh
  assert_success
  
  # Check required top-level fields
  run jq -e '.total_monthly_average_income | type == "number"' data/all-sponsorships.json
  assert_success
  
  run jq -e '.updated_datetime | type == "string"' data/all-sponsorships.json
  assert_success
  
  run jq -e '.current_goal | has("target_amount") and has("progress_percentage")' data/all-sponsorships.json
  assert_success
  
  run jq -e '.monthly_historical_data | type == "object"' data/all-sponsorships.json
  assert_success
  
  run jq -e '.appreciation_message | type == "string"' data/all-sponsorships.json
  assert_success
}

@test "goal progress percentage is calculated correctly" {
  run bash scripts/combine-sponsorships.sh
  assert_success
  
  # Extract values and verify calculation
  total=$(jq -r '.total_monthly_average_income' data/all-sponsorships.json)
  target=$(jq -r '.current_goal.target_amount' data/all-sponsorships.json)
  progress=$(jq -r '.current_goal.progress_percentage' data/all-sponsorships.json)
  
  # Calculate expected progress (with bc for precision)
  expected=$(echo "scale=2; $total * 100 / $target" | bc)
  
  echo "# Total: $total, Target: $target, Progress: $progress, Expected: $expected" >&3
  [ "$progress" = "$expected" ]
}

@test "monthly historical data has correct structure" {
  run bash scripts/combine-sponsorships.sh
  assert_success
  
  # Check that current month is captured
  current_month=$(date -u +'%Y-%m')
  run jq -e --arg month "$current_month" '.monthly_historical_data | has($month)' data/all-sponsorships.json
  assert_success
  
  # Check structure of monthly data
  run jq -e --arg month "$current_month" '.monthly_historical_data[$month] | has("date") and has("total_monthly_average_income")' data/all-sponsorships.json
  assert_success
}

@test "updated_datetime is recent" {
  run bash scripts/combine-sponsorships.sh
  assert_success
  
  # Get timestamp from file
  updated_time=$(jq -r '.updated_datetime' data/all-sponsorships.json)
  
  # Convert to epoch seconds for comparison
  updated_epoch=$(date -d "$updated_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$updated_time" +%s)
  current_epoch=$(date +%s)
  
  # Should be within last 60 seconds
  age=$((current_epoch - updated_epoch))
  echo "# Timestamp age: ${age} seconds" >&3
  [ "$age" -lt 60 ]
}

@test "total calculation matches sum of components" {
  run bash scripts/combine-sponsorships.sh
  assert_success
  
  # Extract component values
  github_ddev=$(jq -r '.github_ddev_sponsorships.total_monthly_sponsorship' data/all-sponsorships.json)
  github_rfay=$(jq -r '.github_rfay_sponsorships.total_monthly_sponsorship' data/all-sponsorships.json)
  monthly_invoiced=$(jq -r '.monthly_invoiced_sponsorships.total_monthly_sponsorship' data/all-sponsorships.json)
  annual_equivalent=$(jq -r '.annual_invoiced_sponsorships.monthly_equivalent_sponsorship' data/all-sponsorships.json)
  paypal=$(jq -r '.paypal_sponsorships' data/all-sponsorships.json)
  total=$(jq -r '.total_monthly_average_income' data/all-sponsorships.json)
  
  # Calculate expected total
  expected=$((github_ddev + github_rfay + monthly_invoiced + annual_equivalent + paypal))
  
  echo "# Components: $github_ddev + $github_rfay + $monthly_invoiced + $annual_equivalent + $paypal = $expected, Got: $total" >&3
  [ "$total" -eq "$expected" ]
}

@test "script doesn't duplicate monthly data on repeated runs" {
  # Run script twice
  run bash scripts/combine-sponsorships.sh
  assert_success
  
  run bash scripts/combine-sponsorships.sh
  assert_success
  
  # Count monthly entries - should still be 1 for current month
  current_month=$(date -u +'%Y-%m')
  count=$(jq --arg month "$current_month" '.monthly_historical_data | keys | length' data/all-sponsorships.json)
  
  echo "# Monthly historical data entries: $count" >&3
  [ "$count" -eq 1 ]
}

@test "github-sponsorships.sh validates required environment variables" {
  # Test missing SPONSORSHIPS_READ_TOKEN
  unset SPONSORSHIPS_READ_TOKEN || true
  run bash -c "SPONSORED_ENTITY_NAME=test SPONSORED_ENTITY_TYPE=user scripts/github-sponsorships.sh"
  assert_failure
  assert_output --partial "Error: GITHUB_TOKEN is not set"
  
  # Test missing SPONSORED_ENTITY_NAME
  run bash -c "SPONSORSHIPS_READ_TOKEN=fake_token SPONSORED_ENTITY_TYPE=user scripts/github-sponsorships.sh"
  assert_failure
  assert_output --partial "Error: ENTITY is not set"
  
  # Test invalid SPONSORED_ENTITY_TYPE
  run bash -c "SPONSORSHIPS_READ_TOKEN=fake_token SPONSORED_ENTITY_NAME=test SPONSORED_ENTITY_TYPE=invalid scripts/github-sponsorships.sh"
  assert_failure
  assert_output --partial "Invalid ENTITY_TYPE specified"
}

@test "data freshness validation" {
  run bash scripts/combine-sponsorships.sh
  assert_success
  
  # Check that timestamp is in ISO format
  run jq -e '.updated_datetime | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' data/all-sponsorships.json
  assert_success
  
  # Verify data looks reasonable (not negative, within expected ranges)
  run jq -e '.total_monthly_average_income >= 0' data/all-sponsorships.json
  assert_success
  
  run jq -e '.current_goal.progress_percentage >= 0' data/all-sponsorships.json
  assert_success
  
  run jq -e '.current_goal.progress_percentage <= 200' data/all-sponsorships.json  # Allow for over-goal
  assert_success
}

@test "calculation with test fixtures" {
  # Copy test fixtures to data directory
  cp tests/testdata/mock-*.jsonc data/
  
  # Run script with predictable test data
  run bash scripts/combine-sponsorships.sh
  assert_success
  
  # With test fixtures: 1000 + 200 + 500 + 100 + 50 = 1850
  run jq -e '.total_monthly_average_income == 1850' data/all-sponsorships.json
  assert_success
  
  # Goal progress: 1850 / 2000 * 100 = 92.50
  run jq -e '.current_goal.progress_percentage == 92.50' data/all-sponsorships.json
  assert_success
  
  # Verify test appreciation message is dynamically generated with progress data
  run jq -e '.appreciation_message | test("Thank you for supporting our test project!")' data/all-sponsorships.json
  assert_success
  
  run jq -e '.appreciation_message | test("93% of our \\$2000/month goal \\(\\$1850/month\\)")' data/all-sponsorships.json
  assert_success
  
  # Verify all components are included
  run jq -e '.github_ddev_sponsorships.total_monthly_sponsorship == 1000' data/all-sponsorships.json
  assert_success
  
  run jq -e '.github_rfay_sponsorships.total_monthly_sponsorship == 200' data/all-sponsorships.json
  assert_success
  
  run jq -e '.monthly_invoiced_sponsorships.total_monthly_sponsorship == 500' data/all-sponsorships.json
  assert_success
  
  run jq -e '.annual_invoiced_sponsorships.monthly_equivalent_sponsorship == 100' data/all-sponsorships.json
  assert_success
  
  run jq -e '.paypal_sponsorships == 50' data/all-sponsorships.json
  assert_success
}

@test "appreciation message is properly extracted from goals" {
  run bash scripts/combine-sponsorships.sh
  assert_success
  
  # Check that appreciation message exists and is non-empty
  run jq -e '.appreciation_message | length > 0' data/all-sponsorships.json
  assert_success
  
  # Check that it contains expected content (emoji and friendly text)
  run jq -e '.appreciation_message | test("❤️|🚀|sponsors|support")' data/all-sponsorships.json
  assert_success
}