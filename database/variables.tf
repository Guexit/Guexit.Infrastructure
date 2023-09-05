variable "postgresql_version" {
  type        = string
  description = "The version of the PostgreSQL server to be deployed."
  default     = "15.2"
}

variable "postgresql_storage_mb" {
  type        = number
  description = "The amount of storage to allocate to the PostgreSQL server in megabytes."
  default     = 32768
}

variable "postgresql_zone" {
  type        = string
  description = "The Azure Availability Zone where the PostgreSQL server will be deployed."
  default     = "1"
}

variable "postgresql_backup_retention_days" {
  type        = number
  description = "The number of days backups will be retained."
  default     = 7
}

variable "postgresql_geo_redundant_backup" {
  type        = bool
  description = "Whether or not to enable geo-redundant backups."
  default     = true
}

variable "postgresql_sku_name" {
  description = "The SKU name for PostgreSQL Flexible Server"
  default     = "GP_Standard_D2s_v3"
}

variable "name_prefix" {
  type        = string
  default     = "postgresqlfs"
  description = "Prefix of the resource name."
}

variable "env_name" {
  description = "The environment name."
  # This is the default. If we want to make it mandatory, then we shouldn't provide it
  default     = "develop"
}