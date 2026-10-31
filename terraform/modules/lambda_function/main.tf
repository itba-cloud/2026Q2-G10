terraform {
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 6.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
  }
}

# Zip y hash propios por funcion para que un cambio en un dominio no redeploye las demas
data "archive_file" "this" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.build/${var.name}.zip"
}

# Lo crea Terraform, no Lambda, para que el destroy lo elimine y no queden grupos huerfanos
# Sin CMK propia, en el lab no creamos llaves KMS (ver docs/arquitectura.md)
#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_lambda_function" "this" {
  function_name = var.name
  role          = var.role_arn
  runtime       = var.runtime
  handler       = var.handler
  memory_size   = var.memory_size
  timeout       = var.timeout
  layers        = var.layers

  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  # Tope de instancias en paralelo para que un flood a una funcion no agote los 400 de la cuenta, -1 no reserva
  reserved_concurrent_executions = var.reserved_concurrency

  # Trazas de X-Ray para observabilidad
  tracing_config {
    mode = "Active"
  }

  # Entra a la VPC solo si se pasa vpc_config, si no corre fuera
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  dynamic "environment" {
    for_each = length(var.environment) > 0 ? [var.environment] : []
    content {
      variables = environment.value
    }
  }

  tags = var.tags

  # El log group tiene que existir antes de que la funcion escriba ahi
  depends_on = [aws_cloudwatch_log_group.this]
}
