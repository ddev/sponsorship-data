# DDEV Sponsorship Data

Daily-updated sponsorship data for the DDEV project, published via GitHub Pages as a JSON API and SVG badges.

## Data Sources

Sponsorship totals are combined from several sources:

- **GitHub Sponsors (`ddev` org)** - fetched daily via [`scripts/github-sponsorships.sh`](scripts/github-sponsorships.sh)
- **GitHub Sponsors (`rfay` user)** - same script; a few long-time sponsors have never switched to the org account
- **Invoiced sponsors** - manually maintained in [`data/invoiced-sponsorships.jsonc`](data/invoiced-sponsorships.jsonc)
- **PayPal** - manually maintained in [`data/paypal-sponsorships.jsonc`](data/paypal-sponsorships.jsonc)

## API

The combined data is published at:

| URL | Notes |
|-----|-------|
| `https://ddev.com/s/sponsorship-data.json` | Preferred short URL |
| `https://ddev.github.io/sponsorship-data/data/all-sponsorships.json` | Direct (backward compatible) |
| `https://ddev.github.io/sponsorship-data/api/all-sponsorships.json` | Direct (new path) |

See the [API index page](https://ddev.github.io/sponsorship-data/) for full documentation.

## SVG Badges

Two sponsorship progress badges are generated daily alongside the JSON data:

| Badge | URL |
|-------|-----|
| Light mode | `https://ddev.github.io/sponsorship-data/badges/sponsorship-badge.svg` |
| Dark mode | `https://ddev.github.io/sponsorship-data/badges/sponsorship-badge-dark.svg` |


## Scripts

| Script | Description |
|--------|-------------|
| [`scripts/github-sponsorships.sh`](scripts/github-sponsorships.sh) | Fetches GitHub Sponsors data for a given org or user via GraphQL |
| [`scripts/combine-sponsorships.sh`](scripts/combine-sponsorships.sh) | Merges all sources into `data/all-sponsorships.json` |
| [`scripts/generate-sponsorship-svg.sh`](scripts/generate-sponsorship-svg.sh) | Generates SVG badges from `data/all-sponsorships.json` |

To regenerate data locally (requires `strip-json-comments-cli` and `jq`):

```bash
scripts/combine-sponsorships.sh
scripts/generate-sponsorship-svg.sh
# SVGs are written to data/tmp/
```

## Sponsorship History

Each daily deploy saves a snapshot to the `history` branch under `data/history/YYYY-MM-DD.json`.

```bash
git fetch origin history
git checkout history
# data/history/ contains all daily snapshots
```

Example - show total monthly income over time:

```bash
for f in data/history/*.json; do
  echo "$(basename $f .json) $(jq '.total_monthly_average_income' < "$f")"
done | sort
```

## Source Files

| File | Description |
|------|-------------|
| [`src/index.html`](src/index.html) | Source for the GitHub Pages index page |
| [`src/github-sponsors.md`](src/github-sponsors.md) | Backup of the [github.com/sponsors/ddev](https://github.com/sponsors/ddev) page description |

## Support DDEV

- [GitHub Sponsors](https://github.com/sponsors/ddev)
- [Support DDEV](https://ddev.com/support-ddev/)
- [DDEV Foundation](https://ddev.com/foundation)
