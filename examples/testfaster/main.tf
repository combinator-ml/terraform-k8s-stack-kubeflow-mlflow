variable "mlflow_namespace" {
  description = "(Optional) The namespace to install into."
  type        = string
  default     = "mlflow"
}

resource "kubernetes_namespace" "mlflow_namespace" {
  metadata {
    name = var.mlflow_namespace
  }
}

module "kubeflow_mlflow_stack" {
  source           = "../../"
  mlflow_namespace = kubernetes_namespace.mlflow_namespace.id
}

resource "kubernetes_service" "istio_external" {
  depends_on = [
    module.kubeflow_mlflow_stack
  ]
  metadata {
    name      = "istio-external"
    namespace = "istio-system"
  }
  spec {
    selector = {
      "app"   = "istio-ingressgateway"
      "istio" = "ingressgateway"
    }
    type = "NodePort"
    port {
      node_port   = 31380
      port        = 80
      target_port = 8080
    }
  }
}

resource "kubernetes_service" "mlflow_external" {
  metadata {
    name      = "mlflow-external"
    namespace = kubernetes_namespace.mlflow_namespace.id
  }
  spec {
    selector = {
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

resource "kubernetes_service" "minio_external" {
  metadata {
    name      = "minio-external"
    namespace = kubernetes_namespace.mlflow_namespace.id
  }
  spec {
    selector = {
      "app" = "minio"
    }
    type = "NodePort"
    port {
      node_port   = 30650
      port        = 9000
      target_port = 9000
    }
  }
}
