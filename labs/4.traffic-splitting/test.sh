#!/bin/bash

v1_count=0
v2_count=0

for i in {1..100}
do
  response=$(curl -sH "Host: cafe.example.com" http://$FQDN/coffee | grep "Server name" | awk '{print $3}')

  if [[ "$response" == *"v1"* ]]; then
    response1_count=$((response1_count + 1))
  elif [[ "$response" == *"v2"* ]]; then
    response2_count=$((response2_count + 1))
  fi
done

echo "Summary of responses:"
echo "Coffee v1: $response1_count times"
echo "Coffee v2: $response2_count times"
