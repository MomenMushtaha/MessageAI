#!/usr/bin/env bash
set -euo pipefail

IAM_USER="${IAM_USER:-messageai-media-uploader}"
BUCKET="${BUCKET:-messageai-media-mm}"

echo "Creating/refreshing IAM user '$IAM_USER' for bucket '$BUCKET'..."

if aws iam get-user --user-name "$IAM_USER" >/dev/null 2>&1; then
  echo "ℹ️ IAM user $IAM_USER already exists (reusing)."
else
  aws iam create-user --user-name "$IAM_USER"
  echo "✅ Created IAM user: $IAM_USER"
fi

cat <<'POLICY' > s3-media-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowMediaReadsWrites",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::messageai-media-mm/*"
      ]
    },
    {
      "Sid": "AllowListBucket",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::messageai-media-mm"
    }
  ]
}
POLICY

aws iam put-user-policy \
  --user-name "$IAM_USER" \
  --policy-name "${IAM_USER}-s3-policy" \
  --policy-document file://s3-media-policy.json

echo "✅ Attached inline policy permitting access to s3://$BUCKET"

ACCESS_JSON=$(aws iam create-access-key --user-name "$IAM_USER")
ACCESS_KEY_ID=$(echo "$ACCESS_JSON" | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(echo "$ACCESS_JSON" | jq -r '.AccessKey.SecretAccessKey')

echo
echo "🎉 AWS access key created."
echo "AccessKeyId:     $ACCESS_KEY_ID"
echo "SecretAccessKey: $SECRET_ACCESS_KEY"
echo
echo "Copy these values somewhere secure—they are shown only once."
echo

rm -f s3-media-policy.json
