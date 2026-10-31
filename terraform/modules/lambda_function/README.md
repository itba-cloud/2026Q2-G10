# Modulo: lambda_function

Empaqueta y crea una funcion Lambda de BarrioFix. Zip y hash propios por funcion
(deploy independiente), log group creado por Terraform (para que el destroy lo
limpie), y soporte opcional de VPC, concurrencia reservada, layers y env vars.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | ~> 2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [archive_file.this](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | Variables de entorno de la funcion | `map(string)` | `{}` | no |
| <a name="input_handler"></a> [handler](#input\_handler) | Handler en formato modulo.funcion | `string` | `"app.handler"` | no |
| <a name="input_layers"></a> [layers](#input\_layers) | ARNs de los layers a adjuntar | `list(string)` | `[]` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retencion de los logs en CloudWatch | `number` | `14` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Memoria en MB, define tambien la CPU asignada | `number` | `1024` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre de la funcion | `string` | n/a | yes |
| <a name="input_reserved_concurrency"></a> [reserved\_concurrency](#input\_reserved\_concurrency) | Concurrencia reservada, -1 no reserva y comparte el pool de la cuenta | `number` | `-1` | no |
| <a name="input_role_arn"></a> [role\_arn](#input\_role\_arn) | ARN del rol de ejecucion, en el lab LabRole | `string` | n/a | yes |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Runtime de la funcion | `string` | `"python3.12"` | no |
| <a name="input_source_dir"></a> [source\_dir](#input\_source\_dir) | Carpeta con el codigo de la funcion que se empaqueta en un zip | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags comunes | `map(string)` | `{}` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Timeout en segundos | `number` | `15` | no |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | Subredes y security groups para la funcion dentro de la VPC, null para fuera | <pre>object({<br/>    subnet_ids         = list(string)<br/>    security_group_ids = list(string)<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | ARN de la funcion |
| <a name="output_function_name"></a> [function\_name](#output\_function\_name) | Nombre de la funcion |
| <a name="output_invoke_arn"></a> [invoke\_arn](#output\_invoke\_arn) | ARN de invocacion para la integracion con API Gateway |
<!-- END_TF_DOCS -->
