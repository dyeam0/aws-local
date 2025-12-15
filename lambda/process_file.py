"""
Lambda function to process S3 file uploads and store metadata in DynamoDB.
Triggered by S3 ObjectCreated events.
"""
import json
import boto3
import os
from datetime import datetime
from urllib.parse import unquote_plus

# Configure endpoint URL for LocalStack
endpoint_url = None
if os.getenv("STAGE") == "local":
    endpoint_url = "https://localhost.localstack.cloud:4566"

s3_client = boto3.client('s3', endpoint_url=endpoint_url)
dynamodb = boto3.resource('dynamodb', endpoint_url=endpoint_url)

def lambda_handler(event, context):
    """
    Process S3 upload event and store file metadata in DynamoDB.
    """
    try:
        # Get DynamoDB table name from environment
        table_name = os.environ.get('DYNAMODB_TABLE', 'file-metadata')
        table = dynamodb.Table(table_name)
        
        # Parse S3 event
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = unquote_plus(record['s3']['object']['key'])
            size = record['s3']['object']['size']
            
            # Get additional file metadata from S3
            try:
                response = s3_client.head_object(Bucket=bucket, Key=key)
                content_type = response.get('ContentType', 'unknown')
                last_modified = response.get('LastModified').isoformat() if response.get('LastModified') else None
            except Exception as e:
                print(f"Error getting S3 metadata: {e}")
                content_type = 'unknown'
                last_modified = None
            
            # Extract file extension
            file_extension = os.path.splitext(key)[1] if '.' in key else ''
            
            # Prepare metadata
            metadata = {
                'file_id': f"{bucket}/{key}",  # Partition key
                'filename': key,
                'bucket': bucket,
                'size_bytes': size,
                'content_type': content_type,
                'file_extension': file_extension,
                'upload_timestamp': datetime.utcnow().isoformat(),
                's3_last_modified': last_modified,
                'processed_by': 'process_file_lambda'
            }
            
            # Store in DynamoDB
            table.put_item(Item=metadata)
            
            print(f"Successfully stored metadata for {key}")
            print(json.dumps(metadata, indent=2))
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'File metadata processed successfully',
                'files_processed': len(event['Records'])
            })
        }
        
    except Exception as e:
        print(f"Error processing file: {str(e)}")
        raise
