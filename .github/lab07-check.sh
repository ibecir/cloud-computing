#!/usr/bin/env bash
# IT 3007 Lab 7 checks. Do not edit: the TA grades with an identical copy.
# Run after setup.sh, send.sh and the two workers. Checks the endpoint in
# AWS_ENDPOINT_URL and prints one PASS or FAIL line per check.
set -u
export AWS_PAGER=""
fails=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
val() { "$@" 2>/dev/null | head -n 1 || true; }

if aws dynamodb describe-table --table-name lab07-orders > /dev/null 2>&1; then
  pass "table: the lab07-orders table exists"
else
  fail "table: there is no lab07-orders table"
fi

QUEUE_URL=$(val aws sqs get-queue-url --queue-name lab07-orders \
  --query QueueUrl --output text)
DLQ_URL=$(val aws sqs get-queue-url --queue-name lab07-orders-dlq \
  --query QueueUrl --output text)
DLQ_ARN=""; QUEUE_ARN=""; REDRIVE=""
if [ -n "$DLQ_URL" ]; then
  DLQ_ARN=$(val aws sqs get-queue-attributes --queue-url "$DLQ_URL" \
    --attribute-names QueueArn --query Attributes.QueueArn --output text)
fi
if [ -n "$QUEUE_URL" ]; then
  QUEUE_ARN=$(val aws sqs get-queue-attributes --queue-url "$QUEUE_URL" \
    --attribute-names QueueArn --query Attributes.QueueArn --output text)
  REDRIVE=$(val aws sqs get-queue-attributes --queue-url "$QUEUE_URL" \
    --attribute-names RedrivePolicy --query Attributes.RedrivePolicy \
    --output text)
fi
if [ -n "$DLQ_ARN" ] && echo "$REDRIVE" | grep -qF "$DLQ_ARN"; then
  pass "redrive: lab07-orders sends failed messages to lab07-orders-dlq"
else
  fail "redrive: lab07-orders and lab07-orders-dlq with a redrive policy needed"
fi

TOPIC_ARN=$(val aws sns list-topics --output text \
  --query "Topics[?ends_with(TopicArn, ':lab07-orders')].TopicArn | [0]")
SUBS=""
if [ -n "$TOPIC_ARN" ] && [ "$TOPIC_ARN" != "None" ]; then
  SUBS=$(val aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" \
    --query "Subscriptions[?Protocol=='sqs'].Endpoint" --output text)
fi
if [ -n "$QUEUE_ARN" ] && echo "$SUBS" | grep -qF "$QUEUE_ARN"; then
  pass "subscription: the lab07-orders topic delivers to the queue"
else
  fail "subscription: no lab07-orders topic subscribed to the queue"
fi

rows=$(val aws dynamodb scan --table-name lab07-orders --select COUNT \
  --query Count --output text)
case "$rows" in ''|*[!0-9]*) rows=0 ;; esac
if [ "$rows" -eq 9 ]; then
  pass "rows: 9 orders are in the table"
else
  fail "rows: expected 9 orders in the table, found $rows"
fi

dlq=0; body=""
if [ -n "$DLQ_URL" ]; then
  dlq=$(val aws sqs get-queue-attributes --queue-url "$DLQ_URL" \
    --attribute-names ApproximateNumberOfMessages \
    --query Attributes.ApproximateNumberOfMessages --output text)
  body=$(val aws sqs receive-message --queue-url "$DLQ_URL" \
    --visibility-timeout 0 --query 'Messages[0].Body' --output text)
fi
case "$dlq" in ''|*[!0-9]*) dlq=0 ;; esac
if [ "$dlq" -eq 1 ] && ! [[ "$body" =~ ^order-[0-9]+,[0-9]+$ ]]; then
  pass "dlq: the poison message is the only message in the DLQ"
else
  fail "dlq: expected exactly 1 poison message in the DLQ, found $dlq"
fi

workers=$(val aws dynamodb scan --table-name lab07-orders \
  --query 'Items[].worker.S' --output text | tr '\t' '\n' \
  | grep -v -e '^None$' -e '^$' | sort -u | grep -c . || true)
case "$workers" in ''|*[!0-9]*) workers=0 ;; esac
if [ "$workers" -ge 2 ]; then
  pass "workers: the orders were shared by $workers workers"
else
  fail "workers: the orders were processed by $workers worker(s), not 2"
fi

[ "$fails" -eq 0 ]
