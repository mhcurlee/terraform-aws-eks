// EBS CSI 




// Add IRSA policy for EBS 

module "ebs_irsa" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version               = "5.4.0"
  role_name             = "ebs-csi-controller-${local.cluster_name}"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-controller-sa"]
    }
  }
}


// add k8s SA

resource "kubernetes_service_account" "ebs_sa" {
  metadata {
    name      = "ebs-controller-sa"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-ebs-csi-driver"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.ebs_irsa.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}


//  Add Helm Chart

resource "helm_release" "aws-ebs-csi-driver" {
  namespace  = "kube-system"
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver/"
  chart      = "aws-ebs-csi-driver"
  #version    = "2.2.8"

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-controller-sa"
  }


  depends_on = [
    kubernetes_service_account.ebs_sa
  ]
}


// Add StorageClass for EBS



resource "kubectl_manifest" "ebs-storageclass" {
  yaml_body = <<-YAML
  kind: StorageClass
  apiVersion: storage.k8s.io/v1
  metadata:
    name: ebs-sc
  provisioner: ebs.csi.aws.com
  volumeBindingMode: WaitForFirstConsumer
  parameters:
    csi.storage.k8s.io/fstype: xfs
    encrypted: "true"
  YAML

  depends_on = [
    helm_release.aws-ebs-csi-driver
  ]
}






