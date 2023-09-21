variable "env_name" {
  description = "The environment name."
  type = string

  validation {
    condition = length(var.env_name) > 0 && length(var.env_name) <= 15
    error_message = "Environment name length must be more than 0 and less or equal than 15"
  }
}
