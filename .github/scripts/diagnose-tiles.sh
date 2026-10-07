#!/usr/bin/env bash
# Asks Google's Map Tiles API directly why the key is refused, with the same
# referrer the site sends. Prints status codes and Google's error text only,
# never the key.
set -u
REF="${SITE:-https://gdhhk-zai.github.io/amahi-3d-site/}"
out=checks/diagnose.txt
mkdir -p checks
redact() { sed -E 's/AIza[A-Za-z0-9_-]+/…/g; s/key=[A-Za-z0-9_-]+/key=…/g' | tr -s ' \n' ' ' | cut -c1-700; }
ask() {
  local label="$1"; shift
  local body code
  body=$(curl -sS -m 30 -w '\n%{http_code}' "$@" 2>&1)
  code=$(printf '%s' "$body" | tail -n1)
  printf '%s: HTTP %s %s\n' "$label" "$code" "$(printf '%s' "$body" | sed '$d' | head -c 900 | redact)" >> "$out"
}
: > "$out"
if [ -z "${GOOGLE_MAPS_KEY:-}" ]; then echo "GOOGLE_MAPS_KEY is not set" >> "$out"; exit 0; fi
K="$GOOGLE_MAPS_KEY"
ask "3D tiles root, with the site's referrer" -H "Referer: $REF" "https://tile.googleapis.com/v1/3dtiles/root.json?key=$K"
ask "3D tiles root, no referrer" "https://tile.googleapis.com/v1/3dtiles/root.json?key=$K"
ask "2D tiles session (same Map Tiles API)" -H "Referer: $REF" -H 'Content-Type: application/json' \
  -d '{"mapType":"satellite","language":"en-US","region":"US"}' "https://tile.googleapis.com/v1/createSession?key=$K"
ask "Street View tiles session (same Map Tiles API)" -H "Referer: $REF" -H 'Content-Type: application/json' \
  -d '{"mapType":"streetview","language":"en-US","region":"US"}' "https://tile.googleapis.com/v1/createSession?key=$K"
ask "Geocoding API (another Maps API, for comparison)" -H "Referer: $REF" "https://maps.googleapis.com/maps/api/geocode/json?address=Riyadh&key=$K"
cat "$out"
