"""GET /images/{imageId} (API Gateway HTTP API, payload v2).

Returns 200 with the DynamoDB item plus https://{CDN_DOMAIN}/{thumbnailKey|webKey}
URLs once COMPLETED, or 404 if the imageId is unknown.
Env: TABLE_NAME, CDN_DOMAIN"""


def handler(event, context):
    raise NotImplementedError("status handler: implemented in a later phase")
