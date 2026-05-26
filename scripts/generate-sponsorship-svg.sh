#!/usr/bin/env bash
set -eu -o pipefail

JSON_FILE="${1:-data/all-sponsorships.json}"
LIGHT_OUTPUT="${2:-data/tmp/sponsorship-badge.svg}"
DARK_OUTPUT="${3:-data/tmp/sponsorship-badge-dark.svg}"

total_monthly=$(jq -r '.total_monthly_average_income' "$JSON_FILE")
goal_target=$(jq -r '.current_goal.target_amount' "$JSON_FILE")
goal_progress=$(jq -r '.current_goal.progress_percentage' "$JSON_FILE")

# Format numbers with commas (portable sed, no locale dependency)
format_commas() {
  printf '%s' "$1" | sed ':a;s/\(.*[0-9]\)\([0-9]\{3\}\)/\1,\2/;ta'
}

total_formatted=$(format_commas "$total_monthly")
target_formatted=$(format_commas "$goal_target")
progress_display=$(printf "%.1f" "$goal_progress")

CARD_W=760
PAD=16
INNER_W=$((CARD_W - 2 * PAD))
BAR_H=8
CARD_H=100

# Logo: viewBox 261.16x199.3, scaled to 16px tall → scale=0.0803, width≈21px
# Positioned at (PAD, 8) so it centers on the 13px title text row (baseline y=22)
LOGO_SCALE=0.0803
LOGO_W=21  # 261.16 * 0.0803 ≈ 21
TITLE_X=$((PAD + LOGO_W + 5))

bar_fill_w=$(awk -v w="$INNER_W" -v p="$goal_progress" 'BEGIN {
  pct = (p > 100 ? 100 : (p < 0 ? 0 : p))
  fill = int(w * pct / 100 + 0.5)
  print (fill > w ? w : (fill < 0 ? 0 : fill))
}')

generate_svg() {
  local text_primary="$1"
  local text_secondary="$2"
  local bar_track="$3"
  local bar_fill_color="$4"
  local output="$5"

  mkdir -p "$(dirname "$output")"

  cat > "$output" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="100%" viewBox="0 0 ${CARD_W} ${CARD_H}" role="img" aria-label="DDEV Sponsorship: \$${total_formatted} / month">
  <title>DDEV Sponsorship: \$${total_formatted} / month</title>
  <g transform="translate(${PAD}, 8) scale(${LOGO_SCALE})" fill="${text_secondary}" fill-rule="evenodd">
    <path d="M116.77,18.59h84.55l45.32,45.33v71.47l-45.32,45.32H125.2a11.84,11.84,0,0,0-8.72-4.07,11.33,11.33,0,1,0,8.72,18.59h82.22l53.74-53.74V57.81L207.42,4.07H116.77A11.82,11.82,0,0,0,108.06,0a11.33,11.33,0,0,0,0,22.66A11.82,11.82,0,0,0,116.77,18.59Zm-8.71-12.2a4.59,4.59,0,0,1,4.64,4.54V11a4.65,4.65,0,0,1-9.29.43,3.09,3.09,0,0,1,0-.43A4.78,4.78,0,0,1,108.06,6.39Zm8.71,176.93a4.65,4.65,0,1,1-4.65,4.65h0a4.58,4.58,0,0,1,4.53-4.65Z"/>
    <path d="M195.5,33.12H87.43v.29a10.58,10.58,0,0,0-8.14-3.49,11.34,11.34,0,1,0,9.3,18H189.4L217.59,76.1v47.35L189.4,151.64H86.85a11.84,11.84,0,0,0-8.72-4.07,11.33,11.33,0,1,0,8.72,18.59H195.21l36.61-36.6V69.73ZM79.29,36.61a4.65,4.65,0,1,1-4.64,4.66v0C74.36,38.64,76.68,36.61,79.29,36.61ZM78.42,154a4.65,4.65,0,1,1-4.65,4.65h0C73.48,156,75.81,154,78.42,154Z"/>
    <path d="M178.65,136.55H47.34a10.75,10.75,0,0,1-7.85,3.19,11.33,11.33,0,1,1,0-22.66,11.59,11.59,0,0,1,9.3,4.94h36l-15.1-15.11H20A11.82,11.82,0,0,1,11.31,111,11.33,11.33,0,1,1,20,92.41H75.81L105.73,122H177.2L188,111.27v-23L177.2,77.57H110.67l15.11,15.11h29.34a11.84,11.84,0,0,1,8.72-4.07,11.33,11.33,0,1,1-8.72,18.59H119.68L90,77.28H50.82a11.85,11.85,0,0,1-8.71,4.07,11.33,11.33,0,1,1,8.71-18.6H183.3l19.47,19.47v35.15L183.3,136.55ZM163.84,94.71a4.65,4.65,0,1,0,4.65,4.65h0C168.78,97,166.45,94.71,163.84,94.71ZM42.4,65.08a4.65,4.65,0,1,0,4.65,4.65A4.78,4.78,0,0,0,42.4,65.08Zm-2.91,58.68a4.65,4.65,0,1,0,4.65,4.65C44.43,125.8,42.11,123.76,39.49,123.76ZM11.6,94.71a4.65,4.65,0,1,0,0,9.3,4.6,4.6,0,0,0,4.65-4.53v-.12A4.78,4.78,0,0,0,11.6,94.71Z"/>
  </g>
  <text x="${TITLE_X}" y="22" font-family="system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif" font-size="15" font-weight="600" fill="${text_secondary}">DDEV Sponsorship</text>
  <text x="${PAD}" y="50" font-family="system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif" font-size="22" font-weight="700" fill="${text_primary}">${progress_display}% towards \$${target_formatted}/month goal</text>
  <rect x="${PAD}" y="60" width="${INNER_W}" height="${BAR_H}" rx="4" fill="${bar_track}"/>
  <rect x="${PAD}" y="60" width="${bar_fill_w}" height="${BAR_H}" rx="4" fill="${bar_fill_color}"/>
  <text x="${PAD}" y="84" font-family="system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif" font-size="15" fill="${text_secondary}">\$${total_formatted} / month</text>
</svg>
EOF

  echo "Generated ${output}" >&2
}

generate_svg "#24292e" "#57606a" "#ccc" "#02a8e2" "$LIGHT_OUTPUT"
generate_svg "#e6edf3" "#8b949e" "#ccc" "#02a8e2" "$DARK_OUTPUT"
