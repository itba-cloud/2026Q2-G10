# Cognito para registro y login con usuario y contraseña, email obligatorio
# Autentica

resource "aws_cognito_user_pool" "this" {
  name = var.project

  username_configuration {
    case_sensitive = false
  }

  # Para la demo el trigger pre-signup confirma las cuentas sin mandar codigo,
  # por eso no auto-verificamos el email
  auto_verified_attributes = []

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    developer_only_attribute = false
    string_attribute_constraints {
      min_length = 1
      max_length = 255
    }
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  # Todo tiene que poder destruirse
  deletion_protection = "INACTIVE"

  # Autoconfirma las cuentas nuevas sin depender del envio de mails
  lambda_config {
    pre_sign_up = module.pre_signup.arn
  }

  tags = local.tags
}

# Dominio de la Hosted UI, con forma <prefijo>.auth.<region>.amazoncognito.com
resource "aws_cognito_user_pool_domain" "this" {
  domain       = local.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.project}-web"
  user_pool_id = aws_cognito_user_pool.this.id

  # El intercambio del code lo hace auth-callback del lado del servidor
  # (patron BFF), por eso el client lleva secreto
  generate_secret = true

  # Flujo OAuth de la Hosted UI, authorization code
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]

  # Solo registramos la URL de callback. El logout es del lado del front (borra
  # los tokens guardados), no cerramos la sesion en Cognito porque necesitaria un
  # bridge /logout con URL HTTPS, igual que el callback
  callback_urls = ["${aws_apigatewayv2_api.http.api_endpoint}/callback"]

  explicit_auth_flows = ["ALLOW_REFRESH_TOKEN_AUTH"]

  # Tokens cortos. El access y el id token duran 1 hora. El navegador no refresca
  # solo (el client tiene secreto, se re-loguea por la Hosted UI), asi que el
  # refresh token casi no se usa y lo dejamos en 1 dia
  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 1
  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

# usuarios de demo

# Mock data
# El perfil en DynamoDB se crea en database.tf con el sub que genera Cognito
resource "aws_cognito_user" "demo" {
  for_each = local.demo_users

  user_pool_id = aws_cognito_user_pool.this.id
  username     = each.key
  password     = var.demo_password

  attributes = {
    email          = each.value.email
    email_verified = true
  }
}
