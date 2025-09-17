#!/bin/bash
# Bash script to attempt a snapraid sync and read temperature readings from smartctl. Report back findings on Slack.
# Requires the SLACK_SNAPRAID_URL to be set, provide the env var by sourcing the appropriate file, below script uses slack_secret.

# CONSTANTS
# SLACK_SNAPRAID_URL (secret)
source ./slack_secret # CHANGE IF USING A DIFFERENT FILE.

# Use with crontab, example below
# 0 1 * * * <script>

# Run SnapRAID commands
snapraid_status_output="$(snapraid status)"
snapraid_sync_output="$(snapraid sync)"
snapraid_sync_status_code=$?
echo "snapraid sync status code: $snapraid_sync_status_code"
#echo $snapraid_status_output
#echo $snapraid_sync_output

# Escape the output for JSON
escaped_status_output=$(printf '%s' "${snapraid_status_output}" | jq -sR .)
escaped_sync_output=$(printf '%s' "${snapraid_sync_output}" | jq -sR .)
#echo $escaped_status_output
echo $escaped_sync_output

temps=""
for disk in /dev/sd?; do
  temp=$(sudo smartctl -A "$disk" | awk '/Temperature_Celsius/ && $1 == 194 {print $10, "C"}')

  temps+="$disk: $temp, "
done
temps+="(less than 50C is good)"
echo "$temps"
escaped_temps=$(printf '%s' "${temps}" | jq -sR .)

# Send output to Slack webhook
json_payload=$(jq -n \
  --arg host "$HOSTNAME" \
  --arg status "$snapraid_sync_status_code" \
  --arg disk_tmps "$temps" \
  '{text: "host=\($host) , status=\($status) (0 is good), disk_tmps=\($disk_tmps)"}')

curl -X POST -H 'Content-type: application/json' --data "$json_payload" "$SLACK_SNAPRAID_URL"


