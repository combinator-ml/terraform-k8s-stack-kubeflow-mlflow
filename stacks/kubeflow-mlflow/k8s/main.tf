provider "kubernetes" {
  config_path    = "./kubeconfig"
  config_context = "minikube"
}

resource "kubernetes_namespace" "example" {
  metadata {
    name = "hello-emilio"
  }
}
