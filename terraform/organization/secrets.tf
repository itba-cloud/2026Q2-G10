# Client secret del app client de Cognito

# recovery_window_in_days = 0 lo borra de inmediato en el destroy 
# para que no nos bloquee la proxima vez que lo intentemos crear

# Sin CMK propia, usamos la llave gestionada por AWS (ver docs/arquitectura.md)
#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "cognito_client" {
  name                    = "${var.project}-cognito-client-secret"
  description             = "Client secret del app client de Cognito (lo usa auth-callback)"
  recovery_window_in_days = 0
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "cognito_client" {
  secret_id     = aws_secretsmanager_secret.cognito_client.id
  secret_string = aws_cognito_user_pool_client.web.client_secret
}
