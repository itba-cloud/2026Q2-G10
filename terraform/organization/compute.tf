# Lambdas y layer comun. Las de API usan el modulo propio lambda_function

# Antes de aplicar hay que correr back/scripts/build.sh, que deja el layer comun
# en back/build/common-layer

# layer comun

data "archive_file" "common_layer" {
  type        = "zip"
  source_dir  = "${path.module}/../../back/build/common-layer"
  output_path = "${path.module}/.build/common-layer.zip"
}

resource "aws_lambda_layer_version" "common" {
  layer_name          = "${var.project}-common"
  filename            = data.archive_file.common_layer.output_path
  source_code_hash    = data.archive_file.common_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]

  lifecycle {
    create_before_destroy = true
  }
}

# Lambdas de API

# Van dentro de la VPC con el layer publico de Powertools y el comun
module "api" {
  source   = "../modules/lambda_function"
  for_each = local.api_functions

  name        = "${var.project}-${each.key}"
  source_dir  = "${path.module}/../../back/functions/${each.key}"
  role_arn    = data.aws_iam_role.lab.arn
  layers      = [var.powertools_layer_arn, aws_lambda_layer_version.common.arn]
  memory_size = var.lambda_memory
  timeout     = var.lambda_timeout

  environment = {
    TABLA        = aws_dynamodb_table.this.name
    MEDIA_BUCKET = awscc_s3_bucket.media.bucket_name
  }

  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags = local.tags
}

# trigger pre sign-up (Cognito)

# Fuera de la VPC, solo marca el evento y no toca datos ni red
module "pre_signup" {
  source = "../modules/lambda_function"

  name       = "${var.project}-pre-signup"
  source_dir = "${path.module}/../../back/functions/cognito_pre_signup"
  role_arn   = data.aws_iam_role.lab.arn
  tags       = local.tags
}

resource "aws_lambda_permission" "cognito_pre_signup" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.pre_signup.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.this.arn
}

# auth-callback (Hosted UI)

# Fuera de la VPC porque llama a Cognito por internet y no toca datos
# Concurrencia reservada porque su endpoint publico es un blanco de floods
module "auth_callback" {
  source = "../modules/lambda_function"

  name                 = "${var.project}-auth-callback"
  source_dir           = "${path.module}/../../back/functions/auth_callback"
  role_arn             = data.aws_iam_role.lab.arn
  timeout              = 10
  reserved_concurrency = var.auth_callback_reserved_concurrency

  environment = {
    TOKEN_ENDPOINT    = "https://${local.cognito_domain_prefix}.auth.${var.region}.amazoncognito.com/oauth2/token"
    CLIENT_ID         = aws_cognito_user_pool_client.web.id
    CLIENT_SECRET_ARN = aws_secretsmanager_secret.cognito_client.arn
    REDIRECT_URI      = "${aws_apigatewayv2_api.http.api_endpoint}/callback"
    FRONT_URL         = local.front_origin
  }

  tags = local.tags
}

resource "aws_lambda_permission" "apigw_auth_callback" {
  statement_id  = "AllowApiGwInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.auth_callback.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# foto-subida (evento S3)

# Dentro de la VPC (escribe en DynamoDB)
# La dispara S3 al llegar una foto
module "foto_subida" {
  source = "../modules/lambda_function"

  name       = "${var.project}-foto-subida"
  source_dir = "${path.module}/../../back/functions/foto_subida"
  role_arn   = data.aws_iam_role.lab.arn
  layers     = [var.powertools_layer_arn, aws_lambda_layer_version.common.arn]

  environment = {
    TABLA        = aws_dynamodb_table.this.name
    MEDIA_BUCKET = awscc_s3_bucket.media.bucket_name
  }

  vpc_config = {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags = local.tags
}

resource "aws_lambda_permission" "s3_foto_subida" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = module.foto_subida.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${awscc_s3_bucket.media.bucket_name}"
}

resource "aws_s3_bucket_notification" "media" {
  bucket = awscc_s3_bucket.media.bucket_name

  lambda_function {
    lambda_function_arn = module.foto_subida.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "solicitudes/"
  }

  # El permiso tiene que existir antes de registrar la notificacion
  depends_on = [aws_lambda_permission.s3_foto_subida]
}

resource "aws_lambda_permission" "apigw_api" {
  for_each = module.api

  statement_id  = "AllowApiGwInvoke"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
