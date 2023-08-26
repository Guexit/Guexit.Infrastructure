variable "postgresql_version" {
  type        = string
  description = "The version of the PostgreSQL server to be deployed."
  default     = "13"
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

variable "postgresql_auto_grow" {
  type        = bool
  description = "Specifies whether the PostgreSQL server should automatically grow storage as required."
  default     = true
}

variable "storage_profile_postgresql" {
  type        = bool
  description = "Specifies whether or not to enable SSL enforcement for PostgreSQL storage."
  default     = true
}

variable "name_prefix" {
  type        = string
  default     = "postgresqlfs"
  description = "Prefix of the resource name."
}
