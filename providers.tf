terraform {
  required_providers {
    k8s = {
      source  = "banzaicloud/k8s"
      version = ">= 0.9.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.3.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.2.0"
    }
  }
  required_version = ">= 0.13"
}
