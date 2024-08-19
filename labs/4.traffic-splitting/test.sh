#!/bin/bash

coffee_v1_count=0
coffee_v2_count=0

for i in {1..100}
do
  response=$(curl -sH "Host: cafe.example.com" http://$FQDN/coffee | grep "Server name" | awk '{print $3}')

  if [[ "$response" == *"v1"* ]]; then
    coffee_v1_count=$((coffee_v1_count + 1))
  elif [[ "$response" == *"v2"* ]]; then
    coffee_v2_count=$((coffee_v2_count + 1))
  fi
done

echo "Summary of responses:"
echo "Coffee v1: $coffee_v1_count times"
echo "Coffee v2: $coffee_v2_count times"
