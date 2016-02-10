#!/bin/sh

op="${1:-op}"
mac="${2:-mac}"
ip="${3:-ip}"
hostname="${4}"

tstamp="`date '+%Y-%m-%d %H:%M:%S'`"

topic="network/dhcp/${mac}"
payload="${op} ${ip} ${tstamp} (${hostname})"

echo $payload >> /tmp/dhcp_script_results
