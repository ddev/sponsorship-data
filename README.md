# DDEV Machine-Readable (JSON) Sponsorship Data

Current information about DDEV's sponsors and current needs.

The data here is accumulated from a few sources:

* `all-sponsorships.json` is the summary of all DDEV sponsors. 
* GitHub Sponsors data for the `ddev` organization is updated daily and automatically by the `github-sponsorships.sh` script here.
* GitHub Sponsors data for the `rfay` user (goes into the same DDEV Foundation bank account) is updated daily and automatically by the `github-sponsorships.sh` script here. (A few sponsors started way back when we didn't have the `ddev` org and have never switched over.)
* The `invoiced-sponsorships.jsonc` and `paypal-sponsorships.jsonc` are manually maintained here when generous donors sign up for these avenues.

## Tools and Scripts

### Sponsorship progress for the past two months

`git log --since="2 months ago" --format="%H %ad" --date=short --reverse -- data/all-sponsorships.json | while read commit date; do   value=$(git show $commit:data/all-sponsorships.json | jq '.["total_monthly_average_income"]');   echo "$date $value"; done`

## DDEV Foundation

To learn more about the DDEV Foundation and its funding, see [DDEV Foundation](https://ddev.com/foundation).

## DDEV Funding

See these resources:

* [Support DDEV](https://ddev.com/support-ddev/)
* [GitHub Sponsors for DDEV](https://github.com/sponsors/ddev)
