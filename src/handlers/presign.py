"""POST /uploads (API Gateway HTTP API, payload v2).

Input body: {"filename": str, "contentType": "image/jpeg|image/png|image/webp"}
Does: new imageId (uuid4), DynamoDB PutItem {imageId, status=PENDING, uploadedAt},
      generate_presigned_post for uploads/{imageId}/{filename} with
      content-length-range 1..MAX_UPLOAD_BYTES and the Content-Type pinned.
Returns 201: {"imageId", "upload": {"url", "fields"}}
Env: SOURCE_BUCKET, TABLE_NAME, MAX_UPLOAD_BYTES"""


def handler(event, context):
    raise NotImplementedError("presign handler: implemented in a later phase")
