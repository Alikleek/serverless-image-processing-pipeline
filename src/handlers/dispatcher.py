"""SQS -> Step Functions dispatcher (event source mapping, ReportBatchItemFailures).

For each SQS record: parse the S3 event body, skip "s3:TestEvent", URL-decode the key,
derive imageId from uploads/{imageId}/{filename}, then
StartExecution(stateMachineArn=STATE_MACHINE_ARN, name=imageId,
               input={"bucket", "key", "imageId"}).
ExecutionAlreadyExists counts as success (duplicate delivery).
Returns {"batchItemFailures": [{"itemIdentifier": messageId}, ...]} for records that failed.
Env: STATE_MACHINE_ARN"""


def handler(event, context):
    raise NotImplementedError("dispatcher handler: implemented in a later phase")
