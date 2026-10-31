provider "aws" {
  region = var.region

  # Tags en todos los recursos que los soporten, para identificar y limpiar todo
  # lo del proyecto con el mismo marcador
  default_tags {
    tags = local.tags
  }
}

provider "awscc" {
  region = var.region
}
