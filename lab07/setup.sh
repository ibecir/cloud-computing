#!/usr/bin/env bash
# IT 3007 Lab 7 - build the pipeline: SNS topic -> SQS queue -> DynamoDB.
# Run it from the root of your repository with:  bash lab07/setup.sh
# Do not add --endpoint-url: AWS_ENDPOINT_URL decides where it runs.
set -euo pipefail
export AWS_PAGER=""

# Part 1: the table, the dead-letter queue and the main queue
aws dynamodb create-table --table-name lab07-orders \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST > /dev/null
aws dynamodb wait table-exists --table-name lab07-orders


DLQ_URL=$(aws sqs create-queue --queue-name lab07-orders-dlq \
  --query QueueUrl --output text)
DLQ_ARN=$(aws sqs get-queue-attributes --queue-url "$DLQ_URL" \
  --attribute-names QueueArn --query Attributes.QueueArn --output text)


REDRIVE=$(printf '{"deadLetterTargetArn":"%s","maxReceiveCount":"2"}' \
  "$DLQ_ARN")
QUEUE_URL=$(aws sqs create-queue --queue-name lab07-orders \
  --attributes "VisibilityTimeout=5,RedrivePolicy='$REDRIVE'" \
  --query QueueUrl --output text)


# Part 2: the topic, subscribed to the main queue
