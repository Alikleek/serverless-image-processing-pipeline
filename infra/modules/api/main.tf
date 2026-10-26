variable "name_prefix" {
  type = string
}

variable "presign_invoke_arn" {
  type = string
}

variable "presign_function" {
  type = string
}

variable "status_invoke_arn" {
  type = string
}

variable "status_function" {
  type = string
}

variable "cors_allowed_origins" {
  type = list(string)
}

variable "throttle_rate" {
  type = number
}

variable "throttle_burst" {
  type = number
}

variable "log_retention_days" {
  type = number
}

locals {
  routes = {
    "POST /uploads"         = { invoke_arn = var.presign_invoke_arn, function = var.presign_function }
    "GET /images/{imageId}" = { invoke_arn = var.status_invoke_arn, function = var.status_function }
  }
}

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.cors_allowed_origins
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 3600
  }
}

resource "aws_apigatewayv2_integration" "this" {
  for_each = local.routes

  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.invoke_arn
  payload_format_version = "2.0"
}

# No authorizer yet: protected by stage throttling only. Add a Cognito JWT
# authorizer here before exposing this beyond a demo.
resource "aws_apigatewayv2_route" "this" {
  for_each = local.routes

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.name_prefix}-api"
  retention_in_days = var.log_retention_days
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.throttle_rate
    throttling_burst_limit = var.throttle_burst
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      latency        = "$context.responseLatency"
      integrationErr = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_lambda_permission" "api" {
  for_each = local.routes

  statement_id  = "AllowApiGateway-${replace(replace(each.key, "/[^A-Za-z0-9]+/", "-"), "/-$/", "")}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

output "api_id" {
  value = aws_apigatewayv2_api.this.id
}

output "api_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}
