"""Step Functions task: validate the uploaded object.

Input: {"bucket", "key", "imageId"}
Checks: size <= MAX_UPLOAD_BYTES, magic bytes are JPEG/PNG/WebP, Pillow can open it,
        width*height under a pixel cap (set Image.MAX_IMAGE_PIXELS).
Returns {"valid": true, "contentType": str}. Raises InvalidImageError otherwise
(caught by the state machine -> MarkFailed).
Env: MAX_UPLOAD_BYTES"""


def handler(event, context):
    raise NotImplementedError("validate handler: implemented in a later phase")
