output "function_name" {
  description = "Nombre de la funcion"
  value       = aws_lambda_function.this.function_name
}

output "arn" {
  description = "ARN de la funcion"
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "ARN de invocacion para la integracion con API Gateway"
  value       = aws_lambda_function.this.invoke_arn
}
