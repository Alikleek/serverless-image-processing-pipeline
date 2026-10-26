"""Step Functions task: web-size (1600px max edge) copy with watermark.

Input: {"bucket", "key", "imageId"}
Resizes, composites the watermark, writes DEST_BUCKET/web/{imageId}.{ext} with
CacheControl="public, max-age=31536000, immutable". Idempotent.
Returns {"key": "web/{imageId}.{ext}"}
Env: DEST_BUCKET"""


def handler(event, context):
    raise NotImplementedError("watermark handler: implemented in a later phase")
