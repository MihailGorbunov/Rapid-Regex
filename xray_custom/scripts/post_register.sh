#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

OUTPUT_DIR="./output"
CONNECTION_FILE="$OUTPUT_DIR/connection.txt"
ENV_FILE="$OUTPUT_DIR/env.txt"
ALL_CONNS_FILE="$OUTPUT_DIR/connections.json"

:

if [[ -z "${REGISTER_URL:-}" ]]; then
  echo "REGISTER_URL is not set; skipping registration"
  exit 0
fi

if [[ ! -f "$CONNECTION_FILE" ]]; then
  echo "Connection file not found: $CONNECTION_FILE"
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE"
  exit 1
fi

if [[ ! -f "$ALL_CONNS_FILE" ]]; then
  echo "Connections file not found: $ALL_CONNS_FILE"
  exit 1
fi

# Read env values as written by xray_prepare.sh (line order: SNI, NAME, USERCOUNT)
read -r SNI_VAL < <(sed -n '1p' "$ENV_FILE") || true
read -r NAME_VAL < <(sed -n '2p' "$ENV_FILE") || true

# Defaults for metadata the user may want to set at runtime
SERVER_NAME="${SERVER_NAME:-${NAME_VAL:-XRAY}}"
DATACENTER="regxa"
PURPOSE="${PURPOSE:-proxy}"

:

PBK=$(jq -r .PBK "$CONNECTION_FILE")
UUID=$(jq -r .UUID "$CONNECTION_FILE")
SID=$(jq -r .SID "$CONNECTION_FILE")
SNI=$(jq -r .SNI "$CONNECTION_FILE")
SERVER_IP=$(jq -r .IP "$CONNECTION_FILE")

:

# Build JSON payload
PAYLOAD=$(jq -n \
  --arg serverName "$SERVER_NAME" \
  --arg datacenter "$DATACENTER" \
  --arg purpose "$PURPOSE" \
  --slurpfile connstrings "$ALL_CONNS_FILE" \
  '{
     serverName: $serverName,
     datacenter: $datacenter,
     purpose: $purpose,
     connstrings: $connstrings[0]
   }')

TMP_HEADERS=$(mktemp)
TMP_BODY=$(mktemp)
TMP_VERBOSE=$(mktemp)

set +e
HTTP_CODE=$(curl -sS -w "%{http_code}" \
  -o "$TMP_BODY" \
  -D "$TMP_HEADERS" \
  -X POST "$REGISTER_URL" \
  -H "Content-Type: application/json" \
  --data "$PAYLOAD" \
  -v 2> "$TMP_VERBOSE")
CURL_STATUS=$?
set -e

if [[ "$CURL_STATUS" -ne 0 || "$HTTP_CODE" -lt 200 || "$HTTP_CODE" -ge 300 ]]; then
  echo "Registration failed (curl=$CURL_STATUS, http=$HTTP_CODE)"
  echo "--- Payload ---"
  echo "$PAYLOAD" | jq . 2>/dev/null || echo "$PAYLOAD"
  echo "--- Response headers ---"
  cat "$TMP_HEADERS"
  echo "--- Response body ---"
  cat "$TMP_BODY"
  echo "--- Curl verbose ---"
  sed 's/^/[curl] /' "$TMP_VERBOSE"
  rm -f "$TMP_HEADERS" "$TMP_BODY" "$TMP_VERBOSE"
  exit 1
fi

rm -f "$TMP_HEADERS" "$TMP_BODY" "$TMP_VERBOSE"
echo "Registration succeeded"


