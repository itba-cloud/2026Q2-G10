# Publica el frontend en el bucket
# config.json (generado por Terraform) + los archivos del dist

# Config que la app lee al arrancar (URL de la API, datos de Cognito)
resource "aws_s3_object" "config" {
  bucket        = awscc_s3_bucket.frontend.bucket_name
  key           = "config.json"
  content_type  = "application/json"
  cache_control = "no-cache"
  content = jsonencode({
    apiUrl           = aws_apigatewayv2_api.http.api_endpoint
    cognitoDomain    = "${local.cognito_domain_prefix}.auth.${var.region}.amazoncognito.com"
    cognitoClientId  = aws_cognito_user_pool_client.web.id
    region           = var.region
    googleMapsApiKey = var.google_maps_api_key
  })
}

# Archivos del dist. for_each sobre fileset
# el etag con filemd5 sube solo lo que cambio
resource "aws_s3_object" "front" {
  for_each = var.front_dist_path == "" ? toset([]) : fileset(var.front_dist_path, "**")

  bucket       = awscc_s3_bucket.frontend.bucket_name
  key          = each.value
  source       = "${var.front_dist_path}/${each.value}"
  etag         = filemd5("${var.front_dist_path}/${each.value}")
  content_type = lookup(local.content_types, lower(reverse(split(".", each.value))[0]), "application/octet-stream")
}
