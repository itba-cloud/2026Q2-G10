# Solo data sources

data "aws_caller_identity" "this" {}

# En el Learner Lab no se pueden crear roles, todas las Lambdas usan este
# Fuera del lab habria que crear un rol por funcion
data "aws_iam_role" "lab" {
  name = var.lab_role_name
}
