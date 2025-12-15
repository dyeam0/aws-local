"""
Lambda function to retrieve all file metadata from DynamoDB.
Provides an API endpoint for the web UI.
"""
import json
import boto3
import os
from decimal import Decimal

# Configure endpoint URL for LocalStack
endpoint_url = None
if os.getenv("STAGE") == "local":
    endpoint_url = "https://localhost.localstack.cloud:4566"

dynamodb = boto3.resource('dynamodb', endpoint_url=endpoint_url)

class DecimalEncoder(json.JSONEncoder):
    """Helper class to convert DynamoDB Decimal types to JSON."""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    """
    Retrieve all file metadata from DynamoDB and return as JSON.
    """
    try:
        # Get DynamoDB table name from environment
        table_name = os.environ.get('DYNAMODB_TABLE', 'file-metadata')
        table = dynamodb.Table(table_name)
        
        # Scan the table to get all items
        response = table.scan()
        items = response.get('Items', [])
        
        # Handle pagination if there are more items
        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            items.extend(response.get('Items', []))
        
        # Sort by upload timestamp (newest first)
        items.sort(key=lambda x: x.get('upload_timestamp', ''), reverse=True)
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET, OPTIONS'
            },
            'body': json.dumps({
                'count': len(items),
                'files': items
            }, cls=DecimalEncoder)
        }
        
    except Exception as e:
        print(f"Error retrieving metadata: {str(e)}")
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
