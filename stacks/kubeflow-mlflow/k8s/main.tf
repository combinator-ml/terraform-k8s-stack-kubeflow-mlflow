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

resource "kubernetes_namespace" "ns" {
  metadata {
    name = "kf"
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

module "mlflow" {
  source  = "terraform-module/release/helm"
  repository = "https://larribas.me/helm-charts"
  namespace  = kubernetes_namespace.ns.metadata.0.name

  app = {
    chart      = "mlflow"
    version    = "1.0.1"
    name       = "mlflow"
    force_update  = true
    wait          = false
    recreate_pods = false
    deploy        = 1
  }

  values = [
    "${file("conf/mlflow_values.yaml")}"
  ]

  set = [
    {
      name  = "prometheus.expose"
      value = true
    }
  ]
}

module "minio" {
  source  = "terraform-module/release/helm"
  repository = "https://helm.min.io/"
  namespace  = kubernetes_namespace.ns.metadata.0.name

  app = {
    chart      = "minio"
    version    = "8.0.9"
    name       = "minio"
    force_update  = true
    wait          = false
    recreate_pods = false
    deploy        = 1
  }

  values = [
    "${file("conf/minio_values.yaml")}"
  ]

  set = [
    {
      name  = "accessKey"
      value = "minio"
    },{
      name  = "secretKey"
      value = "minio-minio"
    },{
      name  = "generate-name"
      value = "minio/minio"
    },{
      name  = "service.port"
      value = 9000
    }
  ]
}

module "mysql" {
  source  = "terraform-module/release/helm"
  repository = "https://charts.bitnami.com/bitnami"
  namespace  = kubernetes_namespace.ns.metadata.0.name

  app = {
    chart      = "mysql"
    version    = "8.0.0"
    name       = "mysql"
    force_update  = true
    wait          = false
    recreate_pods = false
    deploy        = 1
  }

  values = [
    "${file("conf/mysql_values.yaml")}"
  ]

}

resource "kubernetes_service" "mlflow-external" {
  metadata {
    name      = "mlflow-external"
    namespace = kubernetes_namespace.ns.metadata.0.name
  }
  spec {
    selector = {
      "app.kubernetes.io/instance" = "mlflow"
      "app.kubernetes.io/name" = "mlflow"
    }
    type = "NodePort"
    port {
      node_port   = 31380
      port        = 80
      target_port = 80
    }
  }
}

resource "kubernetes_service" "minio-external" {
  metadata {
    name      = "minio-external"
    namespace = kubernetes_namespace.ns.metadata.0.name
  }
  spec {
    selector = {
      "app" = "minio"
      "release" = "minio"
    }
    type = "NodePort"
    port {
      node_port   = 30650
      port        = 9000
      target_port = 9000
    }
  }
}

resource "kubernetes_service" "kubeflow-external" {
  metadata {
    name      = "kubeflow-external"
    namespace = "kubeflow"
  }
  spec {
    selector = {
      "app" = "centraldashboard"
    }
    type = "NodePort"
    port {
      node_port   = 30600
      port        = 8082
      target_port = 8082
    }
  }
  depends_on = [module.kubeflow]
}
