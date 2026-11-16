#!/usr/bin/env bash
# IT 3007 Lab 7 worker: takes orders from the queue and stores them in DynamoDB.
# Usage: bash lab07/worker.sh <worker-name>
# Do not edit: the TA grades with an identical copy of this file.
set -uo pipefail
export AWS_PAGER=""
NAME="${1:-worker}"

QUEUE_URL=$(aws sqs get-queue-url --queue-name lab07-orders \
  --query QueueUrl --output text) || { echo "$NAME: no queue"; exit 1; }

end=$((SECONDS + 90))
while [ "$SECONDS" -lt "$end" ]; do
  # Take one message. Nobody else sees it until the visibility timeout ends.
  msg=$(aws sqs receive-message --queue-url "$QUEUE_URL" \
    --wait-time-seconds 1 --query 'Messages[0].[ReceiptHandle,Body]' \
    --output text)

  if [ -z "$msg" ] || [ "$msg" = "None" ]; then
    # Nothing to take. Stop when no message is waiting or in progress.
    left=$(aws sqs get-queue-attributes --queue-url "$QUEUE_URL" \
      --attribute-names ApproximateNumberOfMessages \
      ApproximateNumberOfMessagesNotVisible --output text \
      --query 'Attributes.[ApproximateNumberOfMessages,
               ApproximateNumberOfMessagesNotVisible]')
    if [ -z "$(echo "$left" | tr -d '0[:space:]')" ]; then
      echo "$NAME: the queue is empty, stopping"
      exit 0
    fi
    continue
  fi

  handle=${msg%%$'\t'*}
  body=${msg#*$'\t'}

  # A valid order looks like "order-3,5": an ID and a quantity.
  if [[ "$body" =~ ^(order-[0-9]+),([0-9]+)$ ]]; then
    id=${BASH_REMATCH[1]}
    qty=${BASH_REMATCH[2]}
    item=$(printf '{"id":{"S":"%s"},"qty":{"N":"%s"},"worker":{"S":"%s"}}' \
      "$id" "$qty" "$NAME")
    aws dynamodb put-item --table-name lab07-orders --item "$item"
    aws sqs delete-message --queue-url "$QUEUE_URL" --receipt-handle "$handle"
    echo "$NAME: stored $id"
  else
    # Not deleted: the message comes back after the visibility timeout,
    # and after too many tries SQS moves it to the dead-letter queue.
    echo "$NAME: cannot process \"$body\", leaving it"
  fi
done
echo "$NAME: time is up, stopping"
