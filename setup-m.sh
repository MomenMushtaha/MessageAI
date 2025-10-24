#!/usr/bin/env bash
set -euo pipefail

MEDIA_BUCKET="messageai-media-mm"          # change if name collision occurs
AWS_REGION="us-east-2"
CF_PRICE_CLASS="PriceClass_All"         # PriceClass_100 | PriceClass_200 | PriceClass_All
ENABLE_VERSIONING="true"                # set to false to skip

echo "📍 Region        : $AWS_REGION"
echo "🪣 Bucket name   : $MEDIA_BUCKET"
echo "💲 Price class   : $CF_PRICE_CLASS"
echo "🌀 Versioning    : $ENABLE_VERSIONING"
echo

aws configure set region "$AWS_REGION" >/dev/null

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# 1. Create S3 bucket (us-east-2 requires LocationConstraint)
if [[ "$AWS_REGION" == "us-east-1" ]]; then
  aws s3api create-bucket --bucket "$MEDIA_BUCKET"
else
  aws s3api create-bucket \
    --bucket "$MEDIA_BUCKET" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi

aws s3api put-public-access-block \
  --bucket "$MEDIA_BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

if [[ "$ENABLE_VERSIONING" == "true" ]]; then
  aws s3api put-bucket-versioning \
    --bucket "$MEDIA_BUCKET" \
    --versioning-configuration Status=Enabled
fi

cat <<'CORS' > "$WORKDIR/cors.json"
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["PUT", "GET", "HEAD"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3000
    }
  ]
}
CORS
aws s3api put-bucket-cors --bucket "$MEDIA_BUCKET" --cors-configuration file://"$WORKDIR/cors.json"

# 2. Origin Access Control
cat <<'OAC' > "$WORKDIR/oac.json"
{
  "Name": "messageai-oac",
  "Description": "CloudFront access control for MessageAI media",
  "SigningProtocol": "sigv4",
  "SigningBehavior": "always",
  "OriginAccessControlOriginType": "s3"
}
OAC
OAC_ID="$(aws cloudfront create-origin-access-control \
  --origin-access-control-config file://"$WORKDIR/oac.json" \
  --query 'OriginAccessControl.Id' --output text)"
echo "✅ Created OAC        : $OAC_ID"

# 3. CloudFront distribution
CALLER_REFERENCE="messageai-$(date +%s)"
cat <<EOF_CF > "$WORKDIR/distribution.json"
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
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
    "OriginRequestPolicyId": "43e97cd0-0b2e-4999-b0dc-e02e0f9f796c"
  },
  "PriceClass": "$CF_PRICE_CLASS",
  "ViewerCertificate": { "CloudFrontDefaultCertificate": true }
}
EOF_CF

DIST_JSON="$(aws cloudfront create-distribution --distribution-config file://"$WORKDIR/distribution.json")"
CF_ID="$(echo "$DIST_JSON" | jq -r '.Distribution.Id')"
CF_ARN="$(echo "$DIST_JSON" | jq -r '.Distribution.ARN')"
CF_DOMAIN="$(echo "$DIST_JSON" | jq -r '.Distribution.DomainName')"

echo "✅ CloudFront ID      : $CF_ID"
echo "🌐 CloudFront domain  : $CF_DOMAIN"

# 4. Bucket policy to allow CloudFront reads
cat <<EOF_BP > "$WORKDIR/bucket-policy.json"
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
EOF_BP
aws s3api put-bucket-policy --bucket "$MEDIA_BUCKET" --policy file://"$WORKDIR/bucket-policy.json"

echo
echo "🎉 AWS resources created."
echo "   Media bucket        : $MEDIA_BUCKET"
echo "   CloudFront domain   : $CF_DOMAIN"
echo "   CloudFront ARN      : $CF_ARN"
echo
echo "⌛ Distribution deploys in ~15 minutes."
echo
echo "Next steps:"
echo "  firebase functions:config:set \\\n    aws.bucket=\"$MEDIA_BUCKET\" \\\n    aws.region=\"$AWS_REGION\" \\\n    aws.cloudfront_domain=\"$CF_DOMAIN\""
echo "  firebase deploy --only functions:generateUploadUrl"
echo "  Update Info.plist S3_UPLOAD_ENDPOINT with your function URL."
echo
echo "Verify once live:"
echo "  aws s3 cp sample.jpg s3://$MEDIA_BUCKET/test/sample.jpg"
echo "  curl -I https://$CF_DOMAIN/test/sample.jpg"
