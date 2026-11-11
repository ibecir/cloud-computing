#!/usr/bin/env bash
# IT 3007 Lab 6 checks. Do not edit: the TA grades with an identical copy.
# Usage: bash .github/lab06-check.sh <github-username> <file with the output of lab06/s3.sh>
# Checks the S3 endpoint in AWS_ENDPOINT_URL and prints one PASS or FAIL line per check.
set -u
export AWS_PAGER=""
user=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
out="$2"
bucket="lab06-$user"
fails=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

status=$(aws s3api get-bucket-versioning --bucket "$bucket" --query Status --output text 2>/dev/null || true)
if [ "$status" = "Enabled" ]; then
  pass "versioning: bucket $bucket exists and versioning is enabled"
else
  fail "versioning: bucket $bucket is missing or versioning is not enabled"
fi

count=$(aws s3api list-objects-v2 --bucket "$bucket" --query 'length(Contents || `[]`)' --output text 2>/dev/null || true)
case "$count" in ''|*[!0-9]*) count=0 ;; esac
if [ "$count" -ge 3 ]; then
  pass "objects: $count objects in $bucket"
else
  fail "objects: expected at least 3 objects in $bucket, found $count"
fi

top=$(aws s3api list-object-versions --bucket "$bucket" --query 'Versions[].Key' --output text 2>/dev/null \
      | tr '\t' '\n' | grep -v -e '^None$' -e '^$' | sort | uniq -c | sort -rn | head -n 1 || true)
n=$(echo "$top" | awk '{print $1}'); key=$(echo "$top" | awk '{print $2}')
case "$n" in ''|*[!0-9]*) n=0 ;; esac
if [ "$n" -ge 2 ]; then
  pass "versions: $key has $n versions"
else
  fail "versions: no object in $bucket has 2 or more versions"
fi

url=$(grep -Eo 'https?://[^[:space:]]+' "$out" 2>/dev/null | tail -n 1 || true)
if [ -z "$url" ]; then
  fail "presign: the script printed no URL"
elif ! echo "$url" | grep -Eq '[?&](X-Amz-Signature|Signature)='; then
  fail "presign: the last URL the script printed is not a presigned URL"
else
  code=$(curl -s -o /dev/null -w '%{http_code}' "$url" || true)
  if [ "$code" = "200" ]; then
    pass "presign: the presigned URL returned 200"
  else
    fail "presign: the presigned URL returned ${code:-no answer}, expected 200"
  fi
fi

[ "$fails" -eq 0 ]
