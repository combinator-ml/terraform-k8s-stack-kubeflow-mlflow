terraform {
  required_providers {
    k8s = {
      version = ">= 0.8.0"
      source  = "banzaicloud/k8s"
    }
    kubernetes = {
      version = "= 1.13.3"
    }
  }
}

provider "kubernetes" {
  config_path    = "/root/.kube/config"
  config_context = "minikube"
}

provider "k8s" {
  config_path    = "/root/.kube/config"
  config_context = "minikube"
}

provider "helm" {
  kubernetes {
   config_path    = "/root/.kube/config"
    config_context = "minikube"
 }
}

resource "kubernetes_namespace" "example2" {
  metadata {
    name = "hello-luke"
  }
}
module "kubeflow" {
  providers = {
    kubernetes = kubernetes
    k8s        = k8s
    helm       = helm
  }

  source  = "datarootsio/kubeflow/module"
  version = "~>0.12"

  #ingress_gateway_ip  = "10.20.30.40"
  use_cert_manager    = true
  install_istio        = true
  install_cert_manager = true
  domain_name         = "foo.local"
  letsencrypt_email   = "foo@bar.local"
  kubeflow_components = ["pipelines"]
}
