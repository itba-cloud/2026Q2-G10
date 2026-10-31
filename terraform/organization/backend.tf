# State remoto en el bucket que crea el bootstrap

# El nombre del bucket lleva el account id y el bloque backend no admite
# variables, por eso se pasa al iniciar
#   terraform init -backend-config="bucket=barriofix-tfstate-<account_id>"

# El lock usa el propio bucket (use_lockfile, Terraform >= 1.10), sin una tabla aparte

terraform {
  backend "s3" {
    key          = "organization/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
