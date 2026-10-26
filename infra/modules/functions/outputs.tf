output "function_arns" {
  value = { for k, f in aws_lambda_function.this : k => f.arn }
}

output "function_names" {
  value = { for k, f in aws_lambda_function.this : k => f.function_name }
}

output "invoke_arns" {
  value = { for k, f in aws_lambda_function.this : k => f.invoke_arn }
}
