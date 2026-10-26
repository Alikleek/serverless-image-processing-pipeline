variable "name_prefix" {
  type = string
}

variable "topic_arn" {
  type = string
}

variable "dlq_name" {
  type = string
}

variable "state_machine_arn" {
  type = string
}

variable "function_names" {
  type = map(string)
}

variable "api_id" {
  type = string
}

locals {
  common = {
    period              = 300
    evaluation_periods  = 1
    threshold           = 0
    comparison_operator = "GreaterThanThreshold"
    treat_missing_data  = "notBreaching"
  }
}

# Anything in the DLQ means a message failed every retry.
resource "aws_cloudwatch_metric_alarm" "dlq" {
  alarm_name          = "${var.name_prefix}-dlq-not-empty"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = var.dlq_name }
  statistic           = "Maximum"
  period              = local.common.period
  evaluation_periods  = local.common.evaluation_periods
  threshold           = local.common.threshold
  comparison_operator = local.common.comparison_operator
  treat_missing_data  = local.common.treat_missing_data
  alarm_actions       = [var.topic_arn]
  ok_actions          = [var.topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "sfn_failed" {
  alarm_name          = "${var.name_prefix}-pipeline-failed"
  namespace           = "AWS/States"
  metric_name         = "ExecutionsFailed"
  dimensions          = { StateMachineArn = var.state_machine_arn }
  statistic           = "Sum"
  period              = local.common.period
  evaluation_periods  = local.common.evaluation_periods
  threshold           = local.common.threshold
  comparison_operator = local.common.comparison_operator
  treat_missing_data  = local.common.treat_missing_data
  alarm_actions       = [var.topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.function_names

  alarm_name          = "${var.name_prefix}-${each.key}-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = each.value }
  statistic           = "Sum"
  period              = local.common.period
  evaluation_periods  = local.common.evaluation_periods
  threshold           = local.common.threshold
  comparison_operator = local.common.comparison_operator
  treat_missing_data  = local.common.treat_missing_data
  alarm_actions       = [var.topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.name_prefix}-api-5xx"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  dimensions          = { ApiId = var.api_id, Stage = "$default" }
  statistic           = "Sum"
  period              = local.common.period
  evaluation_periods  = local.common.evaluation_periods
  threshold           = local.common.threshold
  comparison_operator = local.common.comparison_operator
  treat_missing_data  = local.common.treat_missing_data
  alarm_actions       = [var.topic_arn]
}
