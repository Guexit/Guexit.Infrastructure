variable "postgresql_version" {
  type        = string
  description = "The version of the PostgreSQL server to be deployed."
  default     = "15"
}

variable "postgresql_storage_mb" {
  type        = number
  description = "The amount of storage to allocate to the PostgreSQL server in megabytes."
  default     = 32768
}

variable "env_name" {
  description = "The environment name."
}