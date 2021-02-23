provider "kubernetes" {
  config_path    = "./kubeconfig"
  config_context = "minikube"
}

resource "kubernetes_namespace" "example2" {
  metadata {
    name = "hello-luke"
  }
}
