# LocalStack File Metadata Manager - Deployment Script (PowerShell)
# This script deploys the complete application to LocalStack

$ErrorActionPreference = "Stop"
$env:AWS_DEFAULT_REGION = "us-east-1"

Write-Host "🚀 Deploying File Metadata Manager to LocalStack..." -ForegroundColor Cyan
Write-Host ""

# Create S3 bucket for file uploads
Write-Host "📦 Creating S3 bucket..." -ForegroundColor Yellow
try {
    awslocal s3 mb s3://file-uploads 2>$null
} catch {
    Write-Host "  Bucket already exists" -ForegroundColor Gray
}

# Create DynamoDB table for file metadata
Write-Host "🗄️  Creating DynamoDB table..." -ForegroundColor Yellow
try {
    awslocal dynamodb create-table `
        --table-name file-metadata `
        --attribute-definitions AttributeName=file_id,AttributeType=S `
        --key-schema AttributeName=file_id,KeyType=HASH `
        --billing-mode PAY_PER_REQUEST 2>$null
} catch {
    Write-Host "  Table already exists" -ForegroundColor Gray
}

# Package Lambda functions
Write-Host "📦 Packaging Lambda functions..." -ForegroundColor Yellow

Set-Location lambda
if (Test-Path process_file.zip) { Remove-Item process_file.zip }
if (Test-Path get_metadata.zip) { Remove-Item get_metadata.zip }
if (Test-Path get_presigned_url.zip) { Remove-Item get_presigned_url.zip }

Compress-Archive -Path process_file.py -DestinationPath process_file.zip
Compress-Archive -Path get_metadata.py -DestinationPath get_metadata.zip
Compress-Archive -Path get_presigned_url.py -DestinationPath get_presigned_url.zip
Set-Location ..

Write-Host "✅ Lambda packages created" -ForegroundColor Green

# Deploy Process File Lambda (triggered by S3)
Write-Host "🔧 Creating Process File Lambda..." -ForegroundColor Yellow
try {
    awslocal lambda create-function `
        --function-name process-file `
        --runtime python3.11 `
        --timeout 30 `
        --zip-file fileb://lambda/process_file.zip `
        --handler process_file.handler `
        --role arn:aws:iam::000000000000:role/lambda-role `
        --environment 'Variables={DYNAMODB_TABLE=file-metadata}' 2>$null
} catch {
    Write-Host "  Function exists, updating code..." -ForegroundColor Gray
    awslocal lambda update-function-code `
        --function-name process-file `
        --zip-file fileb://lambda/process_file.zip
}

# Deploy Get Metadata Lambda (API for web UI)
Write-Host "🔧 Creating Get Metadata Lambda..." -ForegroundColor Yellow
try {
    awslocal lambda create-function `
        --function-name get-metadata `
        --runtime python3.11 `
        --timeout 10 `
        --zip-file fileb://lambda/get_metadata.zip `
        --handler get_metadata.handler `
        --role arn:aws:iam::000000000000:role/lambda-role `
        --environment 'Variables={DYNAMODB_TABLE=file-metadata}' 2>$null
} catch {
    Write-Host "  Function exists, updating code..." -ForegroundColor Gray
    awslocal lambda update-function-code `
        --function-name get-metadata `
        --zip-file fileb://lambda/get_metadata.zip
}

# Create function URL for get-metadata
Write-Host "🔗 Creating function URL for get-metadata..." -ForegroundColor Yellow
try {
    awslocal lambda create-function-url-config `
        --function-name get-metadata `
        --auth-type NONE 2>$null
} catch {
    Write-Host "  Function URL already exists" -ForegroundColor Gray
}

# Deploy Get Presigned URL Lambda
Write-Host "🔧 Creating Get Presigned URL Lambda..." -ForegroundColor Yellow
try {
    awslocal lambda create-function-name get-presigned-url `
        --runtime python3.11 `
        --timeout 10 `
        --zip-file fileb://lambda/get_presigned_url.zip `
        --handler get_presigned_url.handler `
        --role arn:aws:iam::000000000000:role/lambda-role `
        --environment 'Variables={S3_BUCKET=file-uploads}' 2>$null
} catch {
    Write-Host "  Function exists, updating code..." -ForegroundColor Gray
    awslocal lambda update-function-code `
        --function-name get-presigned-url `
        --zip-file fileb://lambda/get_presigned_url.zip
}

# Create function URL for get-presigned-url
Write-Host "🔗 Creating function URL for get-presigned-url..." -ForegroundColor Yellow
try {
    awslocal lambda create-function-url-config `
        --function-name get-presigned-url `
        --auth-type NONE 2>$null
} catch {
    Write-Host "  Function URL already exists" -ForegroundColor Gray
}

# Configure S3 bucket notification to trigger process-file Lambda
Write-Host "🔔 Configuring S3 event notification..." -ForegroundColor Yellow
awslocal s3api put-bucket-notification-configuration `
    --bucket file-uploads `
    --notification-configuration '{\"LambdaFunctionConfigurations\": [{\"LambdaFunctionArn\": \"arn:aws:lambda:us-east-1:000000000000:function:process-file\", \"Events\": [\"s3:ObjectCreated:*\"]}]}'

# Deploy website
Write-Host "🌐 Deploying website..." -ForegroundColor Yellow
try {
    awslocal s3 mb s3://file-manager-webapp 2>$null
} catch {
    Write-Host "  Webapp bucket already exists" -ForegroundColor Gray
}
awslocal s3 sync --delete ./website s3://file-manager-webapp
awslocal s3 website s3://file-manager-webapp --index-document index.html

Write-Host ""
Write-Host "✅ Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📋 Lambda Function URLs (copy these into the web app):" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔗 Presign URL Lambda:" -ForegroundColor Yellow
awslocal lambda list-function-url-configs --function-name get-presigned-url --output json | ConvertFrom-Json | Select-Object -ExpandProperty FunctionUrlConfigs | Select-Object -ExpandProperty FunctionUrl
Write-Host ""
Write-Host "🔗 Get Metadata Lambda:" -ForegroundColor Yellow
awslocal lambda list-function-url-configs --function-name get-metadata --output json | ConvertFrom-Json | Select-Object -ExpandProperty FunctionUrlConfigs | Select-Object -ExpandProperty FunctionUrl
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🌐 Web Application URL:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "https://file-manager-webapp.s3-website.localhost.localstack.cloud:4566/" -ForegroundColor White
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📖 Next Steps:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Open the Web Application URL in your browser"
Write-Host "2. Paste the Lambda Function URLs into the configuration section"
Write-Host "3. Click 'Apply Configuration'"
Write-Host "4. Upload a file and watch it appear in the metadata table!"
Write-Host ""
