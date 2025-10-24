#!/usr/bin/env bash
set -euo pipefail

MEDIA_BUCKET="messageai-media-mm"
AWS_REGION="us-east-2"
OAC_ID="${OAC_ID:-EPHH2SRGWFPJL}" # reuse existing Origin Access Control

aws s3api head-bucket --bucket "$MEDIA_BUCKET"

rm -f distribution.json bucket-policy.json

CALLER_REFERENCE="messageai-dist-$(date +%s)"
cat <<JSON > distribution.json
{
  "CallerReference": "$CALLER_REFERENCE",
  "Comment": "MessageAI media CDN",
  "Enabled": true,
  "DefaultRootObject": "",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "s3-$MEDIA_BUCKET",
        "DomainName": "$MEDIA_BUCKET.s3.$AWS_REGION.amazonaws.com",
        "OriginPath": "",
        "S3OriginConfig": { "OriginAccessIdentity": "" },
        "ConnectionAttempts": 3,
        "ConnectionTimeout": 10,
        "OriginShield": { "Enabled": false },
        "OriginAccessControlId": "$OAC_ID"
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "s3-$MEDIA_BUCKET",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"]
    },
    "Compress": true,
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6"
  },
  "PriceClass": "PriceClass_All",
  "ViewerCertificate": { "CloudFrontDefaultCertificate": true }
}
JSON

DIST_JSON=$(aws cloudfront create-distribution --distribution-config file://distribution.json)
CF_ID=$(echo "$DIST_JSON" | jq -r '.Distribution.Id')
CF_ARN=$(echo "$DIST_JSON" | jq -r '.Distribution.ARN')
CF_DOMAIN=$(echo "$DIST_JSON" | jq -r '.Distribution.DomainName')
echo "✅ CloudFront ID      : $CF_ID"
echo "🌐 CloudFront domain  : $CF_DOMAIN"

cat <<JSON > bucket-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipalReadOnly",
      "Effect": "Allow",
      "Principal": { "Service": "cloudfront.amazonaws.com" },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$MEDIA_BUCKET/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "$CF_ARN"
        }
      }
    }
  ]
}
JSON

aws s3api put-bucket-policy --bucket "$MEDIA_BUCKET" --policy file://bucket-policy.json

cat <<EOF

🎉 Done. CloudFront is now deploying (allow ~15 minutes).
Use this domain in Firebase config: $CF_DOMAIN

EOF
