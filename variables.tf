variable "cluster_name" {
  description = "The name of the EKS cluster"
  default     = "marvin-test"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9\\-]*[a-z0-9]$", var.cluster_name))
    error_message = "Cluster name can only contain lower case letters, numbers, and hyphens.  The name must also start and end with a lower case alphanumeric character."
  }

  validation {
    condition     = length(var.cluster_name) < 101
    error_message = "Cluster name has a max size of 100 chars."
  }

}

