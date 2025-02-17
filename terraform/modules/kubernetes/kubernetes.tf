variable "ingestor" {
  type = string
}

variable "data_share_processor_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "container_registry" {
  type = string
}

variable "workflow_manager_image" {
  type = string
}

variable "workflow_manager_version" {
  type = string
}

variable "facilitator_image" {
  type = string
}

variable "facilitator_version" {
  type = string
}

variable "ingestion_bucket" {
  type = string
}


variable "ingestor_manifest_base_url" {
  type = string
}

variable "peer_validation_bucket" {
  type = string
}

variable "peer_manifest_base_url" {
  type = string
}

variable "remote_peer_validation_bucket_identity" {
  type = object({
    identity                                      = string
    gcp_sa_to_impersonate_while_assuming_identity = string
  })
  description = <<DESCRIPTION
Identity to use when writing to the peer's validation bucket. .identity is the
identity that can write to the peer's validation bucket; a GCP service account
email if the peer's bucket is in GCS or an AWS IAM role ARN if the peer's bucket
is in S3. .gcp_sa_to_impersonate_while_assuming_identity is the email of a GCP
service account that must be impersonated to obtain identity tokens for an
identity which will be discovered at runtime in the peer's specific manifest.
Only one or the other value should be set.
DESCRIPTION
}

variable "own_validation_bucket" {
  type = string
}

variable "kubernetes_namespace" {
  type = string
}

variable "packet_decryption_key_kubernetes_secret" {
  type = string
}

variable "portal_server_manifest_base_url" {
  type = string
}

variable "sum_part_bucket_service_account_email" {
  type = string
}

variable "is_first" {
  type = bool
}

variable "intake_max_age" {
  type = string
}

variable "aggregation_period" {
  type = string
}

variable "aggregation_grace_period" {
  type = string
}

variable "pushgateway" {
  type = string
}

variable "intake_queue" {
  type = object({
    name              = string
    topic_kind        = string
    topic             = string
    subscription_kind = string
    subscription      = string
  })
}

variable "aggregate_queue" {
  type = object({
    name              = string
    topic_kind        = string
    topic             = string
    subscription_kind = string
    subscription      = string
  })
}

variable "min_intake_worker_count" {
  type = number
}

variable "max_intake_worker_count" {
  type = number
}

variable "min_aggregate_worker_count" {
  type = number
}

variable "max_aggregate_worker_count" {
  type = number
}

variable "use_aws" {
  type = bool
}

variable "aws_region" {
  type = string
}

variable "eks_oidc_provider" {
  type = object({
    arn = string
    url = string
  })
  default = {
    arn = ""
    url = ""
  }
}

variable "gcp_workload_identity_pool_provider" {
  type = string
}

locals {
  workflow_manager_iam_entity = "${var.environment}-${var.data_share_processor_name}-workflow-manager"
}

module "account_mapping" {
  source                          = "../account_mapping"
  gcp_service_account_name        = var.use_aws ? "" : local.workflow_manager_iam_entity
  gcp_project                     = data.google_project.project.project_id
  aws_iam_role_name               = var.use_aws ? local.workflow_manager_iam_entity : ""
  eks_oidc_provider               = var.eks_oidc_provider
  kubernetes_service_account_name = "${var.data_share_processor_name}-workflow-manager"
  kubernetes_namespace            = var.kubernetes_namespace
  environment                     = var.environment
  allow_gcp_sa_token_creation     = true
}

resource "kubernetes_secret" "batch_signing_key" {
  metadata {
    name      = "${var.environment}-${var.data_share_processor_name}-batch-signing-key"
    namespace = var.kubernetes_namespace
    labels = {
      "isrg-prio.org/type" : "batch-signing-key"
      "isrg-prio.org/ingestor" : var.ingestor
      "isrg-prio.org/locality" : var.kubernetes_namespace
      "isrg-prio.org/instance" : var.data_share_processor_name
    }
  }

  data = {
    # We want this to be a Terraform resource that can be managed and destroyed
    # by this module, but we do not want the cleartext private key to appear in
    # the TF statefile. So we set a dummy value here, and will update the value
    # later using kubectl. We use lifecycle.ignore_changes so that Terraform
    # won't blow away the replaced value on subsequent applies.
    secret_key = "not-a-real-key"
  }

  lifecycle {
    ignore_changes = [
      data["secret_key"]
    ]
  }
}

# ConfigMap containing the parameters that are common to every intake-batch task
# that will be handled in this data share processor, except for secrets.
resource "kubernetes_config_map" "intake_batch_config_map" {
  metadata {
    name      = "${var.data_share_processor_name}-intake-batch-config"
    namespace = var.kubernetes_namespace
  }

  # These key-value pairs will be plopped directly into the container
  # environment, so they MUST match the environment variables set in various
  # Arg::env calls in src/bin/facilitator.rs.
  data = {
    # PACKET_DECRYPTION_KEYS is a Kubernetes secret
    # BATCH_SIGNING_PRIVATE_KEY is a Kubernetes secret
    IS_FIRST                                        = var.is_first ? "true" : "false"
    BATCH_SIGNING_PRIVATE_KEY_IDENTIFIER            = kubernetes_secret.batch_signing_key.metadata[0].name
    INGESTOR_INPUT                                  = var.ingestion_bucket
    INGESTOR_MANIFEST_BASE_URL                      = "https://${var.ingestor_manifest_base_url}"
    INSTANCE_NAME                                   = var.data_share_processor_name
    PEER_IDENTITY                                   = var.remote_peer_validation_bucket_identity.identity
    PEER_MANIFEST_BASE_URL                          = "https://${var.peer_manifest_base_url}"
    PEER_GCP_SA_TO_IMPERSONATE_BEFORE_ASSUMING_ROLE = var.remote_peer_validation_bucket_identity.gcp_sa_to_impersonate_while_assuming_identity
    RUST_LOG                                        = "info"
    RUST_BACKTRACE                                  = "1"
    PUSHGATEWAY                                     = var.pushgateway
    TASK_QUEUE_KIND                                 = var.intake_queue.subscription_kind
    TASK_QUEUE_NAME                                 = var.intake_queue.subscription
    AWS_SQS_REGION                                  = var.use_aws ? var.aws_region : ""
    GCP_PROJECT_ID                                  = var.use_aws ? "" : data.google_project.project.project_id
    GCP_WORKLOAD_IDENTITY_POOL_PROVIDER             = var.gcp_workload_identity_pool_provider
  }
}

# ConfigMap containing the parameters that are common to every aggregation task
# that will be handled in this data share processor, except for secrets.
resource "kubernetes_config_map" "aggregate_config_map" {
  metadata {
    name      = "${var.data_share_processor_name}-aggregate-config"
    namespace = var.kubernetes_namespace
  }

  data = {
    # PACKET_DECRYPTION_KEYS is a Kubernetes secret
    # BATCH_SIGNING_PRIVATE_KEY is a Kubernetes secret
    IS_FIRST                             = var.is_first ? "true" : "false"
    BATCH_SIGNING_PRIVATE_KEY_IDENTIFIER = kubernetes_secret.batch_signing_key.metadata[0].name
    INGESTOR_INPUT                       = var.ingestion_bucket
    INGESTOR_MANIFEST_BASE_URL           = "https://${var.ingestor_manifest_base_url}"
    INSTANCE_NAME                        = var.data_share_processor_name
    PEER_INPUT                           = var.peer_validation_bucket
    PEER_MANIFEST_BASE_URL               = "https://${var.peer_manifest_base_url}"
    PORTAL_IDENTITY                      = var.sum_part_bucket_service_account_email
    PORTAL_MANIFEST_BASE_URL             = "https://${var.portal_server_manifest_base_url}"
    RUST_LOG                             = "info"
    RUST_BACKTRACE                       = "1"
    PUSHGATEWAY                          = var.pushgateway
    TASK_QUEUE_KIND                      = var.aggregate_queue.subscription_kind
    TASK_QUEUE_NAME                      = var.aggregate_queue.subscription
    GCP_PROJECT_ID                       = data.google_project.project.project_id
    AWS_SQS_REGION                       = var.use_aws ? var.aws_region : ""
    GCP_PROJECT_ID                       = var.use_aws ? "" : data.google_project.project.project_id
    PERMIT_MALFORMED_BATCH               = "true"
    GCP_WORKLOAD_IDENTITY_POOL_PROVIDER  = var.gcp_workload_identity_pool_provider
  }
}

data "google_project" "project" {}

resource "kubernetes_cron_job" "workflow_manager" {
  metadata {
    name      = "workflow-manager-${var.ingestor}-${var.environment}"
    namespace = var.kubernetes_namespace

    annotations = {
      environment = var.environment
    }
  }
  spec {
    schedule                      = "*/10 * * * *"
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 5
    failed_jobs_history_limit     = 3
    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            container {
              name  = "workflow-manager"
              image = "${var.container_registry}/${var.workflow_manager_image}:${var.workflow_manager_version}"
              resources {
                requests = {
                  memory = "500Mi"
                  cpu    = "0.5"
                }
                limits = {
                  memory = "8Gi"
                  cpu    = "1.5"
                }
              }

              args = [
                "--aggregation-period", var.aggregation_period,
                "--grace-period", var.aggregation_grace_period,
                "--intake-max-age", var.intake_max_age,
                "--is-first=${var.is_first ? "true" : "false"}",
                "--k8s-namespace", var.kubernetes_namespace,
                "--ingestor-label", var.ingestor,
                "--ingestor-input", var.ingestion_bucket,
                "--own-validation-input", var.own_validation_bucket,
                "--peer-validation-input", var.peer_validation_bucket,
                "--push-gateway", var.pushgateway,
                "--task-queue-kind", var.intake_queue.topic_kind,
                "--intake-tasks-topic", var.intake_queue.topic,
                "--aggregate-tasks-topic", var.aggregate_queue.topic,
                "--gcp-project-id", var.use_aws ? "" : data.google_project.project.project_id,
                "--aws-sns-region", var.use_aws ? var.aws_region : "",
              ]
            }
            # If we use any other restart policy, then when the job is finally
            # deemed to be a failure, Kubernetes will destroy the job, pod and
            # container(s) virtually immediately. This can cause us to lose logs
            # if the container is reaped before the GKE logging agent can upload
            # logs. Since this is a cronjob and we will retry anyway, we use
            # "Never".
            # https://kubernetes.io/docs/concepts/workloads/controllers/job/#handling-pod-and-container-failures
            # https://github.com/kubernetes/kubernetes/issues/74848
            restart_policy                  = "Never"
            service_account_name            = module.account_mapping.kubernetes_service_account_name
            automount_service_account_token = true
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      spec[0].job_template[0].metadata[0].annotations["environment"]
    ]
  }
}

resource "kubernetes_service" "intake_batch" {
  wait_for_load_balancer = false
  metadata {
    name      = "intake-batch-${var.ingestor}"
    namespace = var.kubernetes_namespace
    annotations = {
      # Needed for discovery by Prometheus
      "prometheus.io/scrape" = "true"
    }
  }
  spec {
    port {
      name     = "metrics"
      port     = 8080
      protocol = "TCP"
    }
    type = "ClusterIP"
    # Selector must match the label(s) on kubernetes_deployment.intake_batch
    selector = {
      app      = "intake-batch-worker"
      ingestor = var.ingestor
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["cloud.google.com/neg"]
    ]
  }
}

resource "kubernetes_deployment" "intake_batch" {
  metadata {
    name      = "intake-batch-${var.ingestor}"
    namespace = var.kubernetes_namespace
  }
  spec {
    selector {
      match_labels = {
        app      = "intake-batch-worker"
        ingestor = var.ingestor
      }
    }
    template {
      metadata {
        labels = {
          app      = "intake-batch-worker"
          ingestor = var.ingestor
        }
      }
      spec {
        service_account_name            = module.account_mapping.kubernetes_service_account_name
        automount_service_account_token = false
        container {
          name  = "facile-container"
          image = "${var.container_registry}/${var.facilitator_image}:${var.facilitator_version}"
          args  = ["intake-batch-worker"]
          # Prometheus metrics scrape endpoint
          port {
            container_port = 8080
            protocol       = "TCP"
          }
          resources {
            # Batch intake is single threaded, and we never expect to see
            # batches larger than 3-400 MB, so set the limits such that we can
            # process whole batches in memory (plus a safety margin) and we can
            # use an entire core if necessary. However we set the requests much
            # lower since most batches are much smaller than 3-400 MB and we get
            # more efficient bin packing this way.
            requests = {
              memory = "50Mi"
              cpu    = "0.1"
            }
            limits = {
              memory = "550Mi"
              cpu    = "1.5"
            }
          }
          env {
            name = "BATCH_SIGNING_PRIVATE_KEY"
            value_from {
              secret_key_ref {
                name     = kubernetes_secret.batch_signing_key.metadata[0].name
                key      = "secret_key"
                optional = false
              }
            }
          }
          env {
            name = "PACKET_DECRYPTION_KEYS"
            value_from {
              secret_key_ref {
                name     = var.packet_decryption_key_kubernetes_secret
                key      = "secret_key"
                optional = false
              }
            }
          }
          env_from {
            config_map_ref {
              name     = kubernetes_config_map.intake_batch_config_map.metadata[0].name
              optional = false
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "intake_queue_depth_metric" {
  count = var.use_aws ? 1 : 0
  manifest = {
    apiVersion = "metrics.aws/v1alpha1"
    kind       = "ExternalMetric"
    metadata = {
      namespace = var.kubernetes_namespace
      name      = "${var.ingestor}-intake-queue-depth"
    }
    spec = {
      name = "${var.ingestor}-intake-queue-depth"
      queries = [{
        id = "intake_queue_depth"
        metricStat = {
          metric = {
            namespace  = "AWS/SQS"
            metricName = "ApproximateNumberOfMessagesVisible"
            dimensions = [{
              name  = "QueueName"
              value = var.intake_queue.name
            }]
          }
          period = 60
          stat   = "Average"
          unit   = "Count"
        }
      }]
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "intake_batch_autoscaler" {
  metadata {
    namespace = var.kubernetes_namespace
    name      = "intake-batch-${var.ingestor}-autoscaler"
  }

  spec {
    min_replicas = var.min_intake_worker_count
    max_replicas = var.max_intake_worker_count

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "intake-batch-${var.ingestor}"
    }

    metric {
      type = "External"
      external {
        metric {
          name = var.use_aws ? "${var.ingestor}-intake-queue-depth" : "pubsub.googleapis.com|subscription|num_undelivered_messages"
          selector {
            match_labels = var.use_aws ? {} : {
              "resource.labels.subscription_id" = var.intake_queue.subscription
            }
          }
        }
        target {
          type          = "AverageValue"
          average_value = 1
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 300
        select_policy                = "Max"
        policy {
          period_seconds = 60
          type           = "Pods"
          value          = 1
        }
      }

      scale_down {
        stabilization_window_seconds = 300
        select_policy                = "Max"
        policy {
          period_seconds = 60
          type           = "Pods"
          value          = 1
        }
      }
    }
  }
}

resource "kubernetes_service" "aggregate" {
  wait_for_load_balancer = false
  metadata {
    name      = "aggregate-${var.ingestor}"
    namespace = var.kubernetes_namespace
    annotations = {
      # Needed for discovery by Prometheus
      "prometheus.io/scrape" = "true"
    }
  }
  spec {
    port {
      name     = "metrics"
      port     = 8080
      protocol = "TCP"
    }
    type = "ClusterIP"
    # Selector must match the label(s) on kubernetes_deployment.aggregate
    selector = {
      app      = "aggregate-worker"
      ingestor = var.ingestor
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["cloud.google.com/neg"]
    ]
  }
}

resource "kubernetes_deployment" "aggregate" {
  metadata {
    name      = "aggregate-${var.ingestor}"
    namespace = var.kubernetes_namespace
  }

  spec {
    selector {
      match_labels = {
        app      = "aggregate-worker"
        ingestor = var.ingestor
      }
    }
    template {
      metadata {
        labels = {
          app      = "aggregate-worker"
          ingestor = var.ingestor
        }
      }
      spec {
        service_account_name            = module.account_mapping.kubernetes_service_account_name
        automount_service_account_token = false
        container {
          name  = "facile-container"
          image = "${var.container_registry}/${var.facilitator_image}:${var.facilitator_version}"
          args  = ["aggregate-worker"]
          # Prometheus metrics scrape endpoint
          port {
            container_port = 8080
            protocol       = "TCP"
          }
          resources {
            # As in the intake-batch case, aggregate jobs are single threaded
            # and need to fit whole ingestion batches into memory.
            requests = {
              memory = "50Mi"
              cpu    = "0.1"
            }
            limits = {
              memory = "550Mi"
              cpu    = "1.5"
            }
          }
          env {
            name = "BATCH_SIGNING_PRIVATE_KEY"
            value_from {
              secret_key_ref {
                name     = kubernetes_secret.batch_signing_key.metadata[0].name
                key      = "secret_key"
                optional = false
              }
            }
          }
          env {
            name = "PACKET_DECRYPTION_KEYS"
            value_from {
              secret_key_ref {
                name     = var.packet_decryption_key_kubernetes_secret
                key      = "secret_key"
                optional = false
              }
            }
          }
          env_from {
            config_map_ref {
              name     = kubernetes_config_map.aggregate_config_map.metadata[0].name
              optional = false
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "aggregate_queue_depth_metric" {
  count = var.use_aws ? 1 : 0
  manifest = {
    apiVersion = "metrics.aws/v1alpha1"
    kind       = "ExternalMetric"
    metadata = {
      namespace = var.kubernetes_namespace
      name      = "${var.ingestor}-aggregate-queue-depth"
    }
    spec = {
      name = "${var.ingestor}-aggregate-queue-depth"
      queries = [{
        id = "aggregate_queue_depth"
        metricStat = {
          metric = {
            namespace  = "AWS/SQS"
            metricName = "ApproximateNumberOfMessagesVisible"
            dimensions = [{
              name  = "QueueName"
              value = var.aggregate_queue.name
            }]
          }
          period = 60
          stat   = "Average"
          unit   = "Count"
        }
      }]
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "aggregate_autoscaler" {
  metadata {
    namespace = var.kubernetes_namespace
    name      = "aggregate-${var.ingestor}-autoscaler"
  }

  spec {
    min_replicas = var.min_aggregate_worker_count
    max_replicas = var.max_aggregate_worker_count

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "aggregate-${var.ingestor}"
    }

    metric {
      type = "External"
      external {
        metric {
          name = var.use_aws ? "${var.ingestor}-aggregate-queue-depth" : "pubsub.googleapis.com|subscription|num_undelivered_messages"
          selector {
            match_labels = var.use_aws ? {} : {
              "resource.labels.subscription_id" = var.aggregate_queue.subscription
            }
          }
        }
        target {
          type          = "AverageValue"
          average_value = 1
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 300
        select_policy                = "Max"
        policy {
          period_seconds = 60
          type           = "Pods"
          value          = 1
        }
      }

      scale_down {
        stabilization_window_seconds = 300
        select_policy                = "Max"
        policy {
          period_seconds = 60
          type           = "Pods"
          value          = 1
        }
      }
    }
  }
}

output "gcp_service_account_unique_id" {
  value = module.account_mapping.gcp_service_account_unique_id
}

output "gcp_service_account_email" {
  value = module.account_mapping.gcp_service_account_email
}

output "aws_iam_role" {
  value = module.account_mapping.aws_iam_role
}

output "batch_signing_key" {
  value = kubernetes_secret.batch_signing_key.metadata[0].name
}
