"""Step Functions task: extract image metadata.

Input: {"bucket", "key", "imageId"}
Returns {"width": int, "height": int, "format": str} (optionally EXIF fields later).
The state machine writes these to DynamoDB in StoreMetadata."""


def handler(event, context):
    raise NotImplementedError("metadata handler: implemented in a later phase")
