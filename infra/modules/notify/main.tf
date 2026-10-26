variable "name_prefix" {
  type = string
}

variable "notification_email" {
  type = string
}

# Job completion/failure messages and CloudWatch alarm actions.
#
# Not encrypted with the AWS-managed aws/sns key on purpose: CloudWatch alarms
# cannot publish to topics using that key. Encrypting would need a customer
# managed KMS key (about $1/month) whose policy allows cloudwatch.amazonaws.com
# and states.amazonaws.com.
resource "aws_sns_topic" "events" {
  name = "${var.name_prefix}-events"
}

# Email subscriptions stay "PendingConfirmation" until the link in the email is clicked.
resource "aws_sns_topic_subscription" "email" {
  count = var.notification_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.events.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

output "topic_arn" {
  value = aws_sns_topic.events.arn
}
