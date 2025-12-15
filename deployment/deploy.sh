#!/bin/bash

# LocalStack File Metadata Manager - Deployment Script
# This script deploys the complete application to LocalStack

set -e

export AWS_DEFAULT_REGION=us-east-1

echo "🚀 Deploying File Metadata Manager to LocalStack..."
echo ""

# Create S3 bucket for file uploads
echo "📦 Creating S3 bucket..."
awslocal s3 mb s3://file-uploads 2>/dev/null || echo "  Bucket already exists"

# Create DynamoDB table for file metadata
echo "🗄️  Creating DynamoDB table..."
awslocal dynamodb create-table \
    --table-name file-metadata \
    --attribute-definitions AttributeName=file_id,AttributeType=S \
    --key-schema AttributeName=file_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    2>/dev/null || echo "  Table already exists"

# Wait for table to be active
echo "⏳ Waiting for DynamoDB table to be active..."
awslocal dynamodb wait table-exists --table-name file-metadata

# Package Lambda functions
echo "📦 Packaging Lambda functions..."

# Process File Lambda
(cd lambda; zip -q process_file.zip process_file.py)

# Get Metadata Lambda  
(cd lambda; zip -q get_metadata.zip get_metadata.py)

# Get Presigned URL Lambda
(cd lambda; zip -q get_presigned_url.zip get_presigned_url.py)

echo "✅ Lambda packages created"

# Deploy Process File Lambda (triggered by S3)
echo "🔧 Creating Process File Lambda..."
awslocal lambda create-function \
    --function-name process-file \
    --runtime python3.11 \
    --timeout 30 \
    --zip-file fileb://lambda/process_file.zip \
    --handler process_file.handler \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --environment Variables="{DYNAMODB_TABLE=file-metadata}" \
    2>/dev/null || echo "  Function already exists, updating..."

# Update if it already exists
awslocal lambda update-function-code \
    --function-name process-file \
    --zip-file fileb://lambda/process_file.zip \
    2>/dev/null || true

awslocal lambda wait function-active-v2 --function-name process-file

# Deploy Get Metadata Lambda (API for web UI)
echo "🔧 Creating Get Metadata Lambda..."
awslocal lambda create-function \
    --function-name get-metadata \
    --runtime python3.11 \
    --timeout 10 \
    --zip-file fileb://lambda/get_metadata.zip \
    --handler get_metadata.handler \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --environment Variables="{DYNAMODB_TABLE=file-metadata}" \
    2>/dev/null || echo "  Function already exists, updating..."

awslocal lambda update-function-code \
    --function-name get-metadata \
    --zip-file fileb://lambda/get_metadata.zip \
    2>/dev/null || true

awslocal lambda wait function-active-v2 --function-name get-metadata

# Create function URL for get-metadata
echo "🔗 Creating function URL for get-metadata..."
awslocal lambda create-function-url-config \
    --function-name get-metadata \
    --auth-type NONE \
    2>/dev/null || echo "  Function URL already exists"

# Deploy Get Presigned URL Lambda
echo "🔧 Creating Get Presigned URL Lambda..."
awslocal lambda create-function \
    --function-name get-presigned-url \
    --runtime python3.11 \
    --timeout 10 \
    --zip-file fileb://lambda/get_presigned_url.zip \
    --handler get_presigned_url.handler \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --environment Variables="{S3_BUCKET=file-uploads}" \
    2>/dev/null || echo "  Function already exists, updating..."

awslocal lambda update-function-code \
    --function-name get-presigned-url \
    --zip-file fileb://lambda/get_presigned_url.zip \
    2>/dev/null || true

awslocal lambda wait function-active-v2 --function-name get-presigned-url

# Create function URL for get-presigned-url
echo "🔗 Creating function URL for get-presigned-url..."
awslocal lambda create-function-url-config \
    --function-name get-presigned-url \
    --auth-type NONE \
    2>/dev/null || echo "  Function URL already exists"

# Configure S3 bucket notification to trigger process-file Lambda
echo "🔔 Configuring S3 event notification..."
fn_process_arn=$(awslocal lambda get-function --function-name process-file --output json | jq -r .Configuration.FunctionArn)
awslocal s3api put-bucket-notification-configuration \
    --bucket file-uploads \
    --notification-configuration "{\"LambdaFunctionConfigurations\": [{\"LambdaFunctionArn\": \"$fn_process_arn\", \"Events\": [\"s3:ObjectCreated:*\"]}]}"

# Deploy website
echo "🌐 Deploying website..."
awslocal s3 mb s3://file-manager-webapp 2>/dev/null || echo "  Webapp bucket already exists"
awslocal s3 sync --delete ./website s3://file-manager-webapp
awslocal s3 website s3://file-manager-webapp --index-document index.html

echo ""
echo "✅ Deployment complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Lambda Function URLs (copy these into the web app):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔗 Presign URL Lambda:"
awslocal lambda list-function-url-configs --function-name get-presigned-url --output json | jq -r '.FunctionUrlConfigs[0].FunctionUrl'
echo ""
echo "🔗 Get Metadata Lambda:"
awslocal lambda list-function-url-configs --function-name get-metadata --output json | jq -r '.FunctionUrlConfigs[0].FunctionUrl'
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Web Application URL:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "https://file-manager-webapp.s3-website.localhost.localstack.cloud:4566/"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📖 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Open the Web Application URL in your browser"
echo "2. Paste the Lambda Function URLs into the configuration section"
echo "3. Click 'Apply Configuration'"
echo "4. Upload a file and watch it appear in the metadata table!"
echo ""
echo "🔍 To view resources in LocalStack Web Application:"
echo "   → S3 Buckets: https://app.localstack.cloud/inst/default/resources/s3"
echo "   → DynamoDB Tables: https://app.localstack.cloud/inst/default/resources/dynamodb"
echo "   → Lambda Functions: https://app.localstack.cloud/inst/default/resources/lambda"
echo ""
