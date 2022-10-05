output "host" {
  description = "The API address of the EKS cluster"
  value       = data.aws_eks_cluster.cluster.endpoint
  sensitive   = true
}

output "token" {
  description = "The API token for the EKS cluster"
  value       = data.aws_eks_cluster_auth.cluster.token
  sensitive   = true
}

output "cacert" {
  description = "The CA Cert for the EKS cluster"
  value       = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  sensitive   = true
}
