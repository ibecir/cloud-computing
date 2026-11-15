#!/usr/bin/env bash
# IT 3007 Lab 7 - send 10 messages to the topic: 9 orders and 1 poison message.
# Run it from the root of your repository with:  bash lab07/send.sh
set -euo pipefail
export AWS_PAGER=""

# Part 3: nine orders, then one message that is not an order
# (create-topic returns the existing topic if it already exists)
TOPIC_ARN=$(aws sns create-topic --name lab07-orders \
  --query TopicArn --output text)
for i in 1 2 3 4 5 6 7 8 9; do
  aws sns publish --topic-arn "$TOPIC_ARN" \
    --message "order-$i,$i" > /dev/null
  echo "sent order-$i"
done
aws sns publish --topic-arn "$TOPIC_ARN" \
  --message "this is not an order" > /dev/null
echo "sent the poison message"
