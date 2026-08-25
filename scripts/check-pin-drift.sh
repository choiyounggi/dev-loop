#!/usr/bin/env bash
# dev-loop — detect that a release has not reached users yet.
#
# dev-loop is installed as `dev-loop@groundwork`, and groundwork's marketplace
# entry is TAG-PINNED (`source.ref: vX.Y.Z`). Cutting a tag and publishing a
# Release therefore distributes nothing on its own — the pin has to move too,
# and that hand-step has been skipped before (v1.11.0 shipped while `/plugin`
# still reported 1.10.0). This script compares the two and is run on a schedule
# by .github/workflows/pin-drift.yml, which turns drift into a failed run.
#
# It is a pure comparison: the caller supplies both values (the workflow reads
# them from the GitHub API), so it can be tested and run offline.
#
# Usage: check-pin-drift.sh <latest-release-tag> <groundwork-pinned-ref>
#
# Exit codes:
#   0  in sync — the marketplace pin is the latest release
#   1  drift — the pin is behind (or ahead of) the latest release
#   2  usage error, or an argument that is not a vX.Y.Z tag
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: check-pin-drift.sh <latest-release-tag> <groundwork-pinned-ref>" >&2
  exit 2
fi

LATEST="$1"
PINNED="$2"

for value in "$LATEST" "$PINNED"; do
  if ! printf '%s' "$value" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "check-pin-drift: '$value' is not a vX.Y.Z release tag" >&2
    exit 2
  fi
done

if [ "$LATEST" = "$PINNED" ]; then
  echo "in sync: dev-loop $LATEST is the pinned ref in choiyounggi/groundwork"
  exit 0
fi

# Which side is ahead decides which half of the release checklist was missed.
newest=$(printf '%s\n%s\n' "${LATEST#v}" "${PINNED#v}" | sort -V | tail -1)

echo "DRIFT: dev-loop's latest release is $LATEST but groundwork pins $PINNED" >&2
echo "" >&2
if [ "$newest" = "${LATEST#v}" ]; then
  echo "The release is not reaching users: Claude Code checks out the pinned ref," >&2
  echo "so every install stays on $PINNED. Move the pin:" >&2
  echo "  1. in choiyounggi/groundwork: scripts/sync-dev-loop-pin.sh $LATEST" >&2
  echo "  2. merge that PR (the hourly sync-dev-loop-pin workflow opens one too)" >&2
  echo "  3. /plugin marketplace update groundwork; /plugin update dev-loop@groundwork" >&2
else
  echo "groundwork pins $PINNED, which is newer than the latest dev-loop release." >&2
  echo "The checkout will fail until that tag is released — cut the dev-loop tag" >&2
  echo "and let release.yml publish it, or roll the pin back to $LATEST." >&2
fi
exit 1
