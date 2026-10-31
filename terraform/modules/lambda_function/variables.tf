variable "name" {
  description = "Nombre de la funcion"
  type        = string
}

variable "source_dir" {
  description = "Carpeta con el codigo de la funcion que se empaqueta en un zip"
  type        = string
}

variable "handler" {
  description = "Handler en formato modulo.funcion"
  type        = string
  default     = "app.handler"
}

variable "runtime" {
  description = "Runtime de la funcion"
  type        = string
  default     = "python3.12"
}

variable "role_arn" {
  description = "ARN del rol de ejecucion, en el lab LabRole"
  type        = string
}

variable "layers" {
  description = "ARNs de los layers a adjuntar"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Variables de entorno de la funcion"
  type        = map(string)
  default     = {}
}

variable "memory_size" {
  description = "Memoria en MB, define tambien la CPU asignada"
  type        = number
  default     = 1024
}

variable "timeout" {
  description = "Timeout en segundos"
  type        = number
  default     = 15
}

variable "vpc_config" {
  description = "Subredes y security groups para la funcion dentro de la VPC, null para fuera"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "reserved_concurrency" {
  description = "Concurrencia reservada, -1 no reserva y comparte el pool de la cuenta"
  type        = number
  default     = -1
}

variable "log_retention_days" {
  description = "Retencion de los logs en CloudWatch"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags comunes"
  type        = map(string)
  default     = {}
}
