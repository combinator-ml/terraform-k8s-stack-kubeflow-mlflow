terraform {
  required_providers {
    k8s = {
      version = ">= 0.8.0"
      source  = "banzaicloud/k8s"
    }
    kubernetes = {
      version = "= 1.13.3"
    }
    // TODO: make this switchable (between eks and testfaster)
    aws        = ">= 3.22.0"
    local      = ">= 1.4"
    random     = ">= 2.1"
  }
  required_version = ">= 0.13.1"
}

// TODO: make this switchable (between eks and testfaster)
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

provider "k8s" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
   host                   = data.aws_eks_cluster.cluster.endpoint
   cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
   token                  = data.aws_eks_cluster_auth.cluster.token
 }
}

resource "kubernetes_namespace" "ns" {
  metadata {
    name = "mlflow"
  }
}

module "kubeflow" {
  providers = {
    kubernetes = kubernetes
    k8s        = k8s
    helm       = helm
  }

  // TODO: don't explicitly depend on eks module, make this swappable for testfaster or other cloud backends.
  kubeconfig_file = module.eks.kubeconfig_filename

  source  = "./terraform-module-kubeflow"

  kubeflow_operator_version = "1.2.0"
  kubeflow_version    = "1.1.0"
  use_cert_manager    = true
  install_istio        = true
  install_cert_manager = true
  domain_name         = "kubeflow.local"
  letsencrypt_email   = "hello@combinator.ml"
  #kubeflow_components = ["jupyter", "pipelines"]

  # default login is admin@kubeflow.org and 12341234
}


module "mlflow" {
  source  = "terraform-module/release/helm"
  repository = "./charts"
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
    file("conf/mlflow_values.yaml")
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
    file("conf/minio_values.yaml")
  ]

  set = [
    {
      name  = "accessKey"
      value = "minio"
    },{
      name  = "secretKey"
      value = "minio123"
    },{
      name  = "generate-name"
      value = "minio/minio"
    },{
      name  = "service.port"
      value = 9000
    }
  ]
}

module "prometheus-grafana" {
  source  = "terraform-module/release/helm"
  repository = "./charts"
  namespace  = kubernetes_namespace.ns.metadata.0.name

  app = {
    chart      = "prometheus-grafana"
    version    = "11.1.5"
    name       = "prometheus-grafana"
    force_update  = true
    wait          = false
    recreate_pods = false
    deploy        = 1
  }

  values = [
    file("conf/prometheus_grafana_values.yaml")
  ]

  set = [
    {
      name  = "grafana.adminPassword"
      value = "grafana123"
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
    file("conf/mysql_values.yaml")
  ]

}

resource "kubernetes_secret" "mysql_password" {
  metadata {
    name      = "mlflow-mysql"
    namespace = kubernetes_namespace.ns.metadata.0.name
  }
  data = {
    password = "mysql123"
  }
}

resource "kubernetes_service" "mlflow_external" {
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
      node_port   = 30600
      port        = 80
      target_port = 80
    }
  }
}

resource "kubernetes_service" "grafana_external" {
  metadata {
    name      = "grafana-external"
    namespace = kubernetes_namespace.ns.metadata.0.name
  }
  spec {
    selector = {
      "app.kubernetes.io/instance" = "prometheus-grafana"
      "app.kubernetes.io/name" = "grafana"
    }
    type = "NodePort"
    port {
      node_port   = 30650
      port        = 80
      target_port = 3000
    }
  }
}

resource "kubernetes_service" "istio_external" {
  metadata {
    name      = "istio-external"
    namespace = "istio-system"
  }
  spec {
    selector = {
      "app" = "istio-ingressgateway"
      "istio" = "ingressgateway"
    }
    type = "NodePort"
    port {
      node_port   = 31380
      port        = 80
      target_port = 8080
    }
  }
  depends_on = [module.kubeflow]
}
