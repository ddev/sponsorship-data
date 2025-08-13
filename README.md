# DDEV Machine-Readable (JSON) Sponsorship Data

Current information about DDEV's sponsors and current needs.

The data here is accumulated from a few sources:

* `all-sponsorships.json` is the summary of all DDEV sponsors, deployed via GitHub Pages at:
  - **https://ddev.github.io/sponsorship-data/data/all-sponsorships.json** (API endpoint)
* GitHub Sponsors data for the `ddev` organization is updated daily and automatically by the `github-sponsorships.sh` script here.
* GitHub Sponsors data for the `rfay` user (goes into the same DDEV Foundation bank account) is updated daily and automatically by the `github-sponsorships.sh` script here. (A few sponsors started way back when we didn't have the `ddev` org and have never switched over.)
* The `invoiced-sponsorships.jsonc` and `paypal-sponsorships.jsonc` are manually maintained here when generous donors sign up for these avenues.

## API Usage

The sponsorship data is available as a [JSON file](https://ddev.com/s/sponsorship-data.json), which redirects to this repository's GitHub Pages at [https://ddev.github.io/sponsorship-data/data/all-sponsorships.json](https://ddev.github.io/sponsorship-data/data/all-sponsorships.json)

## Tools and Scripts

### Sponsorship History

To provide sponsorship history (previously available via git history of `all-sponsorships.json`), each daily deployment now saves a snapshot of the data in `data/history/YYYY-MM-DD.json`.  
**These snapshots are committed to the `history` branch of this repository.**  
You can analyze sponsorship changes over time by checking out the `history` branch:

```bash
git fetch origin history
git checkout history
# Now data/history/ contains all snapshots
```

#### Example: Show total monthly average income over time

```bash
for f in data/history/*.json; do
  date=$(basename $f .json)
  value=$(jq '.["total_monthly_average_income"]' < "$f")
  echo "$date $value"
done | sort
```

### Sponsorship progress for the past two months

`git log --since="2 months ago" --format="%H %ad" --date=short --reverse -- data/all-sponsorships.json | while read commit date; do   value=$(git show $commit:data/all-sponsorships.json | jq '.["total_monthly_average_income"]');   echo "$date $value"; done`

_Note: For recent history, use the new `data/history/` snapshots in the `history` branch as described above._

## DDEV Foundation

To learn more about the DDEV Foundation and its funding, see [DDEV Foundation](https://ddev.com/foundation).

## DDEV Funding

See these resources:

* [Support DDEV](https://ddev.com/support-ddev/)
* [GitHub Sponsors for DDEV](https://github.com/sponsors/ddev)

