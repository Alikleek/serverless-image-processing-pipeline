"""Step Functions task: 256px thumbnail.

Input: {"bucket", "key", "imageId"}
Writes DEST_BUCKET/thumbnails/{imageId}.{ext} with
CacheControl="public, max-age=31536000, immutable". Idempotent (same key every time).
Returns {"key": "thumbnails/{imageId}.{ext}"}
Env: DEST_BUCKET"""


def handler(event, context):
    raise NotImplementedError("thumbnail handler: implemented in a later phase")
