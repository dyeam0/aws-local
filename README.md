# File Metadata Manager - LocalStack TPM Challenge

A simple AWS serverless application that demonstrates S3, Lambda, and DynamoDB integration using LocalStack.

## Overview

This application allows users to:
1. Upload files to an S3 bucket
2. Automatically extract and store file metadata in DynamoDB
3. View all uploaded file metadata through a web interface

## Architecture

```
┌─────────────┐
│   Web UI    │
│  (S3 Site)  │
└──────┬──────┘
       │
       ├─────────────────┐
       │                 │
       ▼                 ▼
┌──────────────┐  ┌──────────────┐
│  Presign     │  │ Get Metadata │
│   Lambda     │  │    Lambda    │
└──────┬───────┘  └──────┬───────┘
       │                 │
       ▼                 ▼
┌──────────────┐  ┌──────────────┐
│  S3 Bucket   │  │  DynamoDB    │
│file-uploads  │  │file-metadata │
└──────┬───────┘  └──────────────┘
       │
       │ (S3 Event)
       ▼
┌──────────────┐
│Process File  │
│   Lambda     │
└──────┬───────┘
       │
       └──────────────────┐
                          ▼
                   ┌──────────────┐
                   │  DynamoDB    │
                   │file-metadata │
                   └──────────────┘
```

## Components

### Lambda Functions

1. **process_file.py** - Triggered by S3 ObjectCreated events
   - Extracts file metadata (name, size, type, timestamp)
   - Stores metadata in DynamoDB
   
2. **get_metadata.py** - API endpoint for web UI
   - Retrieves all file metadata from DynamoDB
   - Returns JSON response with CORS headers

3. **get_presigned_url.py** - Generates S3 upload URLs
   - Creates presigned POST URLs for secure file uploads
   - Used by web UI to upload files directly to S3

### Infrastructure

- **S3 Buckets**
  - `file-uploads` - Stores uploaded files
  - `file-manager-webapp` - Hosts static website

- **DynamoDB Table**
  - `file-metadata` - Stores file metadata
  - Partition key: `file_id` (format: bucket/filename)

### Web Interface

- Single-page HTML application
- Upload files via drag-and-drop or file picker
- View all file metadata in a table
- Auto-refreshes after uploads

## Setup Instructions

### Prerequisites

- LocalStack running locally
- AWS CLI installed
- `awslocal` wrapper installed
- Python 3.11+

### Deployment

1. Navigate to the project directory:
   ```bash
   cd aws-local
   ```

2. Run the deployment script:
   
   **On Linux/Mac:**
   ```bash
   chmod +x deployment/deploy.sh
   ./deployment/deploy.sh
   ```
   
   **On Windows (PowerShell):**
   ```powershell
   cd deployment
   .\deploy.ps1
   ```

3. Copy the Lambda function URLs from the output

4. Open the web application URL in your browser

5. Paste the Lambda URLs into the configuration section

6. Upload files and view their metadata!

## Testing

### Upload a File
1. Open the web UI
2. Configure Lambda URLs
3. Select a file using the file picker
4. Click "Upload"
5. Wait for success message
6. Click "Refresh" to see the metadata

### View in LocalStack Web Application
1. Go to https://app.localstack.cloud/
2. Navigate to Resources > S3 to see uploaded files
3. Navigate to Resources > DynamoDB to see metadata entries
4. Navigate to Resources > Lambda to see function invocations

## File Metadata Structure

Each file entry in DynamoDB contains:
- `file_id`: Unique identifier (bucket/filename)
- `filename`: Name of the file
- `bucket`: S3 bucket name
- `size_bytes`: File size in bytes
- `content_type`: MIME type
- `file_extension`: File extension
- `upload_timestamp`: ISO timestamp of when processed
- `s3_last_modified`: S3 last modified timestamp
- `processed_by`: Lambda function that processed it

## Cleanup

To remove all resources:
```bash
awslocal s3 rb s3://file-uploads --force
awslocal s3 rb s3://file-manager-webapp --force
awslocal dynamodb delete-table --table-name file-metadata
awslocal lambda delete-function --function-name process-file
awslocal lambda delete-function --function-name get-metadata
awslocal lambda delete-function --function-name get-presigned-url
```

## Development Notes

### Environment Variables
- `DYNAMODB_TABLE`: DynamoDB table name (default: file-metadata)
- `S3_BUCKET`: S3 bucket for uploads (default: file-uploads)

### Testing Lambda Functions Directly

Test process-file Lambda:
```bash
echo '{"Records":[{"s3":{"bucket":{"name":"file-uploads"},"object":{"key":"test.txt","size":100}}}]}' | awslocal lambda invoke --function-name process-file --payload file:///dev/stdin response.json
```

Test get-metadata Lambda:
```bash
awslocal lambda invoke --function-name get-metadata response.json
cat response.json
```

## License

MIT
