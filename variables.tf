variable "cluster_name" {
  description = "The name of the EKS cluster"

  validation {
    condition     = can(regex("^[0-9a-z\\-]*$", var.cluster_name))
    error_message = "Cluster name can only contain lower case letters, numbers, and hyphens."
  }

  validation {
    condition     = length(var.cluster_name) < 101
    error_message = "Cluster name has a max size of 100 chars."
  }

}

