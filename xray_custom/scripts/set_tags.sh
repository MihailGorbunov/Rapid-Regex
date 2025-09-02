#!/bin/bash
set -e

cd "$(dirname "$0")"

CONNECTION_FILE="./output/connection.txt"
AUTH_RESULT="./output/auth_result.txt"
mkdir -p "$(dirname "$AUTH_RESULT")"

# Проверка авторизации
if aws sts get-caller-identity --output json > /tmp/sts.json 2>/tmp/sts.err; then
    echo "[SUCCESS] Authorized as:" > "$AUTH_RESULT"
    jq . /tmp/sts.json >> "$AUTH_RESULT"
else
    echo "[FAILURE] Authorization failed:" > "$AUTH_RESULT"
    cat /tmp/sts.err >> "$AUTH_RESULT"
    cat "$AUTH_RESULT"
    exit 1
fi

# Получаем Task ARN из ECS metadata
TASK_METADATA_URL="${ECS_CONTAINER_METADATA_URI_V4}/task"
TASK_METADATA=$(curl -s "$TASK_METADATA_URL")
echo "Metadata: $TASK_METADATA"
TASK_ARN=$(echo $TASK_METADATA | jq -r .TaskARN)

if [[ -z "$TASK_ARN" ]]; then
    echo "Could not determine ECS Task ARN"
    exit 1
fi

# Парсим JSON из connection.txt
if [[ ! -f "$CONNECTION_FILE" ]]; then
    echo "Connection file not found: $CONNECTION_FILE"
    exit 1
fi

PBK=$(jq -r .PBK "$CONNECTION_FILE")
UUID=$(jq -r .UUID "$CONNECTION_FILE")
SID=$(jq -r .SID "$CONNECTION_FILE")
SNI=$(jq -r .SNI "$CONNECTION_FILE")
IP=$(jq -r .IP "$CONNECTION_FILE")

# Устанавливаем теги на ECS Task
aws resourcegroupstaggingapi tag-resources \
  --resource-arn-list "$TASK_ARN" \
  --tags PBK="$PBK",UUID="$UUID",SID="$SID",SNI="$SNI",IP="$IP"

echo "Tags updated successfully for ECS task: $TASK_ARN"