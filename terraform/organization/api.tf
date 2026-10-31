# API Gateway HTTP API, entrada HTTPS a las Lambdas

# El JWT authorizer de Cognito valida el token antes de invocar la Lambda
# Las rutas publicas (catalogos, /callback) no lo llevan

# El throttling del stage es la primera defensa ante floods, rechaza el exceso con 429

resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project}-http"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [local.front_origin]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["authorization", "content-type"]
    max_age       = 3000
  }

  tags = local.tags
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.http.id
  name             = "cognito"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.web.id]
    issuer   = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.this.id}"
  }
}

# integraciones y rutas de API

resource "aws_apigatewayv2_integration" "api" {
  for_each = module.api

  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "api" {
  for_each = local.api_routes

  api_id    = aws_apigatewayv2_api.http.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.api[each.value.fn].id}"

  authorization_type = each.value.public ? "NONE" : "JWT"
  authorizer_id      = each.value.public ? null : aws_apigatewayv2_authorizer.cognito.id
}

# ruta publica /callback

resource "aws_apigatewayv2_integration" "auth_callback" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = module.auth_callback.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "callback" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /callback"
  target    = "integrations/${aws_apigatewayv2_integration.auth_callback.id}"
}

# stage

# Sin access logging, para esta entrega alcanzan los logs de las Lambdas (ver docs/arquitectura.md)
#tfsec:ignore:aws-api-gateway-enable-access-logging
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.api_throttle_rate
    throttling_burst_limit = var.api_throttle_burst
  }

  tags = local.tags
}
