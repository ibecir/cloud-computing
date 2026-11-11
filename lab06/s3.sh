#!/usr/bin/env bash
# IT 3007 Lab 6 - my S3 script.
# Run it from the root of your repository with:  bash lab06/s3.sh
# It uses the S3 endpoint in AWS_ENDPOINT_URL: Floci on your computer, Floci in
# GitHub Actions, and Floci on the TA's computer when it is graded.
# Do not add --endpoint-url to the commands below.
set -euo pipefail
export AWS_PAGER=""

BUCKET="lab06-ibecir"

# Part 1: create the bucket and turn on versioning
aws s3api create-bucket --bucket "$BUCKET"
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled

# Part 2: upload three objects, and a second version of one of them
echo "<h1>Hello from $BUCKET</h1>" | aws s3 cp - "s3://$BUCKET/index.html" --content-type text/html
echo "id,name" | aws s3 cp - "s3://$BUCKET/data.csv"
echo "first version" | aws s3 cp - "s3://$BUCKET/notes.txt"
echo "second version" | aws s3 cp - "s3://$BUCKET/notes.txt"
aws s3api list-object-versions --bucket "$BUCKET" --query "Versions[].[Key,IsLatest]" --output text

# Part 3: print a presigned URL (this must be the last thing the script prints)
aws s3 presign "s3://$BUCKET/index.html" --expires-in 600
