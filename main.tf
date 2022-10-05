// EKS module 


locals {
  cluster_name    = var.cluster_name
  node_group_name = "ng1"
}


data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id

}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id

}

data "aws_caller_identity" "current" {}

locals {
  role_principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
}


# add roles for k8s access

resource "aws_iam_role" "k8s-admin-role" {
  name = "eks-k8s-admin-role-${local.cluster_name}"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          "AWS" : "${local.role_principal_arn}"
        }
      },
    ]
  })

  tags = {
    tag-key = "EKS-${local.cluster_name}"
  }
}


resource "aws_iam_role" "k8s-dev-role" {
  name = "eks-k8s-dev-role-${local.cluster_name}"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          "AWS" : "${local.role_principal_arn}"
        }
      },
    ]
  })

  tags = {
    tag-key = "EKS-${local.cluster_name}"
  }
}

resource "aws_kms_key" "eks" {
  description             = "EKS Secret Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}



resource "aws_iam_policy" "efs-csi-node-policy" {
  name        = "efs-csi-node-policy"
  description = "EFS CIS policy for nodes"

  policy = jsonencode({

    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticfilesystem:DescribeMountTargets",
          "ec2:DescribeAvailabilityZones"
        ],
        "Resource" : "*"
      }
    ]
  })
}




module "eks" {
  source                        = "terraform-aws-modules/eks/aws"
  version                       = "18.30.0"
  cluster_name                  = local.cluster_name
  cluster_version               = "1.22"
  cluster_enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  vpc_id                        = module.vpc.vpc_id
  subnet_ids                    = module.vpc.private_subnets
  enable_irsa                   = true
  create_cluster_security_group = false
  create_node_security_group    = false
  manage_aws_auth_configmap     = true

  cluster_encryption_config = [
    {
      provider_key_arn = aws_kms_key.eks.arn
      resources        = ["secrets"]
    }
  ]


  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.k8s-admin-role.arn
      username = "admin-user"
      groups   = ["system:masters"]
    },
    {
      rolearn  = aws_iam_role.k8s-dev-role.arn
      username = "dev-user"
      groups   = [""]
    }
  ]



  eks_managed_node_groups = {
    (local.node_group_name) = {
      instance_types                        = ["t3.medium"]
      ami_type                              = "BOTTLEROCKET_x86_64"
      create_security_group                 = false
      attach_cluster_primary_security_group = true
      key_name                              = "ec2-ohio"

      min_size     = 2
      max_size     = 2
      desired_size = 2

      iam_role_additional_policies = [
        # Required by Karpenter
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        aws_iam_policy.efs-csi-node-policy.id
      ]
    }
  }

  tags = {
    # Tag node group resources for Karpenter auto-discovery
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    "karpenter.sh/discovery" = local.cluster_name
  }


}

