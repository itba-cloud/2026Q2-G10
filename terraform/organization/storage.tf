# Dos buckets
#   frontend  sitio estatico publico (website endpoint)
#   media     fotos privadas, se acceden con URLs prefirmadas

# frontend

resource "awscc_s3_bucket" "frontend" {
  bucket_name = local.bucket_front

  # Sin versionado a proposito, el sitio se reconstruye entero en cada deploy

  website_configuration = {
    index_document = "index.html"
    # El router del front es client-side, cualquier ruta cae en index.html
    error_document = "index.html"
  }

  # Para servir el sitio hay que permitir el acceso publico de la bucket policy
  public_access_block_configuration = {
    block_public_acls       = false
    block_public_policy     = false
    ignore_public_acls      = false
    restrict_public_buckets = false
  }
}

resource "awscc_s3_bucket_policy" "frontend" {
  bucket = awscc_s3_bucket.frontend.id
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "LecturaPublica"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "arn:aws:s3:::${local.bucket_front}/*"
    }]
  })
}

# media

resource "awscc_s3_bucket" "media" {
  bucket_name = local.bucket_media

  # Versionado con limpieza de versiones viejas
  # protege contra borrados sin dejar que el bucket crezca para siempre
  versioning_configuration = {
    status = "Enabled"
  }

  lifecycle_configuration = {
    rules = [{
      id     = "expirar-versiones-viejas"
      status = "Enabled"
      noncurrent_version_expiration = {
        noncurrent_days = 30
      }
    }]
  }

  # El navegador sube las fotos directo con presigned POST, por eso hace falta CORS
  cors_configuration = {
    cors_rules = [{
      allowed_headers = ["*"]
      allowed_methods = ["GET", "POST", "PUT"]
      allowed_origins = [local.front_origin]
      max_age_seconds = 3000
    }]
  }

  public_access_block_configuration = {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}
