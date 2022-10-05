// EFS CSI 



// SG for access to EFS targets

resource "aws_security_group" "efs-sg" {
  name        = "allow_nfs"
  description = "Allow NFS inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "TCP 2049 NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

}


// Create EFS FS

resource "aws_efs_file_system" "foo" {
  creation_token = "efs-csi"
  encrypted      = "true"

  tags = {
    Name = "EFS-CSI"
  }
}


// Add mount targets to the private subnets

resource "aws_efs_mount_target" "alpha" {
  count           = length(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.foo.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs-sg.id]
}


// Add IRSA policy for EFS 

module "efs_irsa" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version               = "5.4.0"
  role_name             = "efs-controller-${local.cluster_name}"
  attach_efs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-controller-sa"]
    }
  }
}


// add k8s SA

resource "kubernetes_service_account" "efs_sa" {
  metadata {
    name      = "efs-controller-sa"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-efs-csi-driver"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.efs_irsa.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}


//  Add Helm Chart

resource "helm_release" "aws-efs-csi-driver" {
  namespace  = "kube-system"
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  version    = "2.2.8"

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "efs-controller-sa"
  }

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.us-east-2.amazonaws.com/eks/aws-efs-csi-driver"
  }

  depends_on = [
    kubernetes_service_account.efs_sa
  ]
}

// Add StorageClass for EFS



resource "kubectl_manifest" "efs-storageclass" {
  yaml_body = <<-YAML
  kind: StorageClass
  apiVersion: storage.k8s.io/v1
  metadata:
    name: efs-sc
  provisioner: efs.csi.aws.com
  parameters:
    provisioningMode: efs-ap
    fileSystemId: ${aws_efs_file_system.foo.id} 
    directoryPerms: "700"
    gidRangeStart: "1000" # optional
    gidRangeEnd: "2000" # optional
    basePath: "/dynamic_provisioning" # optional
  YAML

  depends_on = [
    helm_release.aws-efs-csi-driver
  ]
}





