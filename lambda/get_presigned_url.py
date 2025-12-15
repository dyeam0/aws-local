"""
Lambda function to generate S3 presigned POST URLs for file uploads.
"""
import json
import boto3
import os

# Configure endpoint URL for LocalStack
endpoint_url = None
if os.getenv("STAGE") == "local":
    endpoint_url = "https://localhost.localstack.cloud:4566"

s3_client = boto3.client('s3', endpoint_url=endpoint_url)

def lambda_handler(event, context):
    """
    Generate a presigned POST URL for uploading files to S3.
    Expects filename in the URL path (e.g., /myfile.txt)
    """
    try:
        # Get filename from URL path
        key = event.get("rawPath", "").lstrip("/")
        if not key:
            # Fallback to query parameter or body
            params = event.get("queryStringParameters") or {}
            key = params.get("filename")
            if not key and event.get("body"):
                try:
                    body = json.loads(event["body"]) if isinstance(event["body"], str) else event["body"]
                    key = body.get("filename")
                except:
                    pass
        
        if not key:
            key = "unnamed-file"
        
        # Get bucket name from environment
        bucket = os.environ.get('S3_BUCKET', 'file-uploads')
        
        # Generate presigned POST URL
        presigned_post = s3_client.generate_presigned_post(
            Bucket=bucket,
            Key=key,
            ExpiresIn=3600  # URL valid for 1 hour
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps(presigned_post)
        }
        
    except Exception as e:
        print(f"Error generating presigned URL: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }
