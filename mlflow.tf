module "mlflow" {
  source    = "combinator-ml/mlflow/k8s"
  version   = "0.0.3"
  namespace = var.mlflow_namespace
}
