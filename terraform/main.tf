variable "environment" {
  type = string
}

variable "gcp_region" {
  type = string
}

variable "gcp_project" {
  type = string
}

variable "use_aws" {
  type    = bool
  default = false
}

variable "pure_gcp" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
A data share processor that runs on GCP (i.e., use_aws=false) will still manage
some resources in AWS (IAM roles) _unless_ this variable is set to true.
DESCRIPTION
}

variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "localities" {
  type = list(string)
}

variable "ingestors" {
  type = map(object({
    manifest_base_url = string
    localities = map(object({
      intake_worker_count     = optional(number) # Deprecated: set {min,max}_intake_worker_count instead.
      min_intake_worker_count = optional(number)
      max_intake_worker_count = optional(number)

      aggregate_worker_count     = optional(number) # Deprecated: set {min,max}_aggregate_worker_count instead.
      min_aggregate_worker_count = optional(number)
      max_aggregate_worker_count = optional(number)

      peer_share_processor_manifest_base_url = optional(string)
      portal_server_manifest_base_url        = optional(string)
      aggregation_period                     = optional(string)
      aggregation_grace_period               = optional(string)
    }))
  }))
  description = <<DESCRIPTION
Map of ingestor names to per-ingestor configuration.
peer_share_processor_manifest_base_url is optional and overrides
default_peer_share_processor_manifest_base_url for the locality.
portal_server_manifest_base_url is optional and overrides
default_portal_server_manifest_base_url for the locality.
aggregation_period and aggregation_grace_period values are optional and override
default_aggregation_period and default_aggregation_grace_period, respectively,
for the locality. The values should be strings parseable by Go's
time.ParseDuration.
DESCRIPTION
}

variable "manifest_domain" {
  type        = string
  description = "Domain (plus optional relative path) to which this environment's global and specific manifests should be uploaded."
}

variable "managed_dns_zone" {
  type = object({
    name        = string
    gcp_project = string
  })
  default = {
    name        = ""
    gcp_project = ""
  }
}

variable "test_peer_environment" {
  type = object({
    env_with_ingestor            = string
    env_without_ingestor         = string
    localities_with_sample_maker = list(string)
  })
  default = {
    env_with_ingestor            = ""
    env_without_ingestor         = ""
    localities_with_sample_maker = []
  }
  description = <<DESCRIPTION
Describes a pair of data share processor environments set up to test against
each other. One environment, named in "env_with_ingestor", hosts a fake
ingestion servers, but only for the localities enumerated in
"localities_with_sample_makers", which should be a subset of the ones in
"localities". The other environment, named in "env_without_ingestor", has no
fake ingestion servers. This variable should not be specified in production
deployments.
DESCRIPTION
}

variable "is_first" {
  type        = bool
  default     = false
  description = "Whether the data share processors created by this environment are \"first\" or \"PHA servers\""
}

variable "intake_max_age" {
  type        = string
  default     = "6h"
  description = <<DESCRIPTION
Maximum age of ingestion batches for workflow-manager to schedule intake tasks
for. The value should be a string parseable by Go's time.ParseDuration.
DESCRIPTION
}

variable "default_aggregation_period" {
  type        = string
  default     = "3h"
  description = <<DESCRIPTION
Aggregation period used by workflow manager if none is provided by the locality
configuration. The value should be a string parseable by Go's
time.ParseDuration.
DESCRIPTION
}

variable "default_aggregation_grace_period" {
  type        = string
  default     = "1h"
  description = <<DESCRIPTION
Aggregation grace period used by workflow manager if none is provided by the locality
configuration. The value should be a string parseable by Go's
time.ParseDuration.
DESCRIPTION
}

variable "default_peer_share_processor_manifest_base_url" {
  type        = string
  description = <<DESCRIPTION
Base URL relative to which the peer share processor's manifests can be found, if
none is provided by the locality configuration.
DESCRIPTION
}

variable "default_portal_server_manifest_base_url" {
  type        = string
  description = <<DESCRIPTION
Base URL relative to which the portal server's manifests can be found, if none
is provided by the locality configuration.
DESCRIPTION
}

variable "batch_signing_key_expiration" {
  type        = number
  default     = 390
  description = "This value is used to generate batch signing keys with the specified expiration"
}

variable "batch_signing_key_rotation" {
  type        = number
  default     = 300
  description = "This value is used to specify the rotation interval of the batch signing key"
}

variable "packet_encryption_key_expiration" {
  type        = number
  default     = 90
  description = "This value is used to generate packet encryption keys with the specified expiration"
}

variable "packet_encryption_rotation" {
  type        = number
  default     = 50
  description = "This value is used to specify the rotation interval of the packet encryption key"
}

variable "pushgateway" {
  type        = string
  default     = "prometheus-pushgateway.monitoring:9091"
  description = "The location of a pushgateway in host:port form. Set to prometheus-pushgateway.default:9091 to enable metrics"
}

variable "container_registry" {
  type    = string
  default = "letsencrypt"
}

variable "workflow_manager_image" {
  type    = string
  default = "prio-workflow-manager"
}

variable "workflow_manager_version" {
  type    = string
  default = "latest"
}

variable "facilitator_image" {
  type    = string
  default = "prio-facilitator"
}

variable "facilitator_version" {
  type    = string
  default = "latest"
}

variable "prometheus_server_persistent_disk_size_gb" {
  type = number
  # This is quite high, but it's the minimum for GCE regional disks
  default = 200
}

variable "victorops_routing_key" {
  type        = string
  default     = "bogus-routing-key"
  description = "VictorOps/Splunk OnCall routing key for prometheus-alertmanager"
}

variable "cluster_settings" {
  type = object({
    initial_node_count = number
    min_node_count     = number
    max_node_count     = number
    gcp_machine_type   = string
    aws_machine_types  = list(string)
  })
}

terraform {
  backend "gcs" {}

  required_version = ">= 0.14.8"

  # https://www.terraform.io/docs/language/expressions/type-constraints.html#experimental-optional-object-type-attributes
  experiments = [module_variable_optional_attrs]

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.62.0"
    }
    google = {
      source = "hashicorp/google"
      # Ensure that this matches the google-beta provider version below.
      version = "~> 3.86.0"
    }
    google-beta = {
      source = "hashicorp/google-beta"
      # Ensure that this matches the non-beta google provider version above.
      version = "~> 3.86.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 2.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    # `tls` provider needed to load EKS cluster OIDC provider certificate
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.1.0"
    }
  }
}

data "terraform_remote_state" "state" {
  backend = "gcs"

  workspace = "${var.environment}-${var.gcp_region}"

  config = {
    bucket = "${var.environment}-${var.gcp_region}-prio-terraform"
  }
}

data "google_project" "current" {}
data "google_client_config" "current" {}
data "aws_caller_identity" "current" {}

provider "google" {
  # This will use "Application Default Credentials". Run `gcloud auth
  # application-default login` to generate them.
  # https://www.terraform.io/docs/providers/google/guides/provider_reference.html#credentials
  region  = var.gcp_region
  project = var.gcp_project
}

provider "google-beta" {
  # Duplicate settings from the non-beta provider
  region  = var.gcp_region
  project = var.gcp_project
}

provider "aws" {
  # aws_s3_bucket resources will be created in the region specified in this
  # provider.
  # https://github.com/hashicorp/terraform/issues/12512
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      "prio-env" = var.environment
    }
  }
}

provider "kubernetes" {
  host                   = local.kubernetes_cluster.endpoint
  cluster_ca_certificate = base64decode(local.kubernetes_cluster.certificate_authority_data)
  token                  = local.kubernetes_cluster.token
  experiments {
    manifest_resource = true
  }
}

provider "helm" {
  kubernetes {
    host                   = local.kubernetes_cluster.endpoint
    cluster_ca_certificate = base64decode(local.kubernetes_cluster.certificate_authority_data)
    token                  = local.kubernetes_cluster.token
  }
}

module "manifest_gcp" {
  source                  = "./modules/manifest_gcp"
  count                   = var.use_aws ? 0 : 1
  environment             = var.environment
  gcp_region              = var.gcp_region
  global_manifest_content = local.global_manifest
  managed_dns_zone        = var.managed_dns_zone
}

module "manifest_aws" {
  source                  = "./modules/manifest_aws"
  count                   = var.use_aws ? 1 : 0
  environment             = var.environment
  global_manifest_content = local.global_manifest
}

module "gke" {
  source           = "./modules/gke"
  count            = var.use_aws ? 0 : 1
  environment      = var.environment
  resource_prefix  = "prio-${var.environment}"
  gcp_region       = var.gcp_region
  gcp_project      = var.gcp_project
  cluster_settings = var.cluster_settings
}

module "eks" {
  source           = "./modules/eks"
  count            = var.use_aws ? 1 : 0
  environment      = var.environment
  resource_prefix  = "prio-${var.environment}"
  cluster_settings = var.cluster_settings
}

# While we create a distinct data share processor for each (ingestor, locality)
# pair, we only create one packet decryption key for each locality, and use it
# for all ingestors. Since the secret must be in a namespace and accessible
# from all of our data share processors, that means all data share processors
# associated with a given ingestor must be in a single Kubernetes namespace,
# which we create here and pass into the data share processor module.
resource "kubernetes_namespace" "namespaces" {
  for_each = toset(var.localities)
  metadata {
    name = each.key
    annotations = {
      environment = var.environment
    }
  }
}

resource "kubernetes_secret" "ingestion_packet_decryption_keys" {
  for_each = toset(var.localities)
  metadata {
    name      = "${var.environment}-${each.key}-ingestion-packet-decryption-key"
    namespace = kubernetes_namespace.namespaces[each.key].metadata[0].name
  }

  data = {
    # See comment on batch_signing_key, in modules/kubernetes/kubernetes.tf,
    # about the initial value and the lifecycle block here.
    secret_key = "not-a-real-key"
  }

  lifecycle {
    ignore_changes = [
      data["secret_key"]
    ]
  }
}

# We will receive ingestion batches from multiple ingestion servers for each
# locality. We create a distinct data share processor for each (locality,
# ingestor) pair. e.g., "us-pa-apple" processes data for Pennsylvanians received
# from Apple's server, and "us-az-g-enpa" processes data for Arizonans received
# from Google's server.
# We take the set product of localities x ingestor names to get the config
# values for all the data share processors we need to create.
locals {
  locality_ingestor_pairs = {
    for pair in setproduct(toset(var.localities), keys(var.ingestors)) :
    "${pair[0]}-${pair[1]}" => {
      ingestor                                = pair[1]
      locality                                = pair[0]
      kubernetes_namespace                    = kubernetes_namespace.namespaces[pair[0]].metadata[0].name
      packet_decryption_key_kubernetes_secret = kubernetes_secret.ingestion_packet_decryption_keys[pair[0]].metadata[0].name
      ingestor_manifest_base_url              = var.ingestors[pair[1]].manifest_base_url
      min_intake_worker_count = coalesce(
        var.ingestors[pair[1]].localities[pair[0]].min_intake_worker_count,
        var.ingestors[pair[1]].localities[pair[0]].intake_worker_count
      )
      max_intake_worker_count = coalesce(
        var.ingestors[pair[1]].localities[pair[0]].max_intake_worker_count,
        var.ingestors[pair[1]].localities[pair[0]].intake_worker_count
      )
      min_aggregate_worker_count = coalesce(
        var.ingestors[pair[1]].localities[pair[0]].min_aggregate_worker_count,
        var.ingestors[pair[1]].localities[pair[0]].aggregate_worker_count
      )
      max_aggregate_worker_count = coalesce(
        var.ingestors[pair[1]].localities[pair[0]].max_aggregate_worker_count,
        var.ingestors[pair[1]].localities[pair[0]].aggregate_worker_count
      )
      peer_share_processor_manifest_base_url = coalesce(
        var.ingestors[pair[1]].localities[pair[0]].peer_share_processor_manifest_base_url,
        var.default_peer_share_processor_manifest_base_url
      )
      portal_server_manifest_base_url = coalesce(
        var.ingestors[pair[1]].localities[pair[0]].portal_server_manifest_base_url,
        var.default_portal_server_manifest_base_url
      )
      aggregation_period = coalesce(
        var.ingestors[pair[1]].localities[pair[0]].aggregation_period,
        var.default_aggregation_period
      )
      aggregation_grace_period = coalesce(
        var.ingestors[pair[1]].localities[pair[0]].aggregation_grace_period,
        var.default_aggregation_grace_period
      )
    }
  }
  # Are we in a paired env deploy that uses a test ingestor?
  deployment_has_ingestor = lookup(var.test_peer_environment, "env_with_ingestor", "") == "" ? false : true
  # Does this specific environment home the ingestor?
  is_env_with_ingestor = local.deployment_has_ingestor && lookup(var.test_peer_environment, "env_with_ingestor", "") == var.environment ? true : false

  # If pure GCP, we use the newer global manifest format
  global_manifest = var.pure_gcp ? jsonencode({
    format = 1
    server-identity = {
      gcp-service-account-id    = var.use_aws ? null : tostring(google_service_account.sum_part_bucket_writer.unique_id)
      gcp-service-account-email = google_service_account.sum_part_bucket_writer.email
    }
    }) : jsonencode({
    format = 0
    server-identity = {
      aws-account-id            = tonumber(data.aws_caller_identity.current.account_id)
      gcp-service-account-email = google_service_account.sum_part_bucket_writer.email
    }
  })

  manifest = var.use_aws ? {
    bucket      = module.manifest_aws[0].bucket
    bucket_url  = module.manifest_aws[0].bucket_url
    base_url    = module.manifest_aws[0].base_url
    aws_region  = var.aws_region
    aws_profile = var.aws_profile
    } : {
    bucket      = module.manifest_gcp[0].bucket
    bucket_url  = module.manifest_gcp[0].bucket_url
    base_url    = module.manifest_gcp[0].base_url
    aws_region  = ""
    aws_profile = ""
  }

  kubernetes_cluster = var.use_aws ? {
    name                       = module.eks[0].cluster_name
    endpoint                   = module.eks[0].cluster_endpoint
    certificate_authority_data = module.eks[0].certificate_authority_data
    token                      = module.eks[0].token
    kubectl_command            = "aws --profile ${var.aws_profile} eks update-kubeconfig --region ${var.aws_region} --name ${module.eks[0].cluster_name}"
    } : {
    name                       = module.gke[0].cluster_name
    endpoint                   = module.gke[0].cluster_endpoint
    certificate_authority_data = module.gke[0].certificate_authority_data
    token                      = module.gke[0].token
    kubectl_command            = "gcloud container clusters get-credentials ${module.gke[0].cluster_name} --region ${var.gcp_region} --project ${var.gcp_project}"
  }
}

# Call the locality_kubernetes module for each locality/namespace
module "locality_kubernetes" {
  for_each             = kubernetes_namespace.namespaces
  source               = "./modules/locality_kubernetes"
  environment          = var.environment
  use_aws              = var.use_aws
  gcp_project          = var.gcp_project
  manifest_bucket      = local.manifest.bucket
  kubernetes_namespace = each.value.metadata[0].name
  ingestors            = keys(var.ingestors)
  eks_oidc_provider    = var.use_aws ? module.eks[0].oidc_provider : { url = "", arn = "" }

  batch_signing_key_expiration     = var.batch_signing_key_expiration
  batch_signing_key_rotation       = var.batch_signing_key_rotation
  packet_encryption_key_expiration = var.packet_encryption_key_expiration
  packet_encryption_rotation       = var.packet_encryption_rotation
}

module "data_share_processors" {
  for_each                                       = local.locality_ingestor_pairs
  source                                         = "./modules/data_share_processor"
  environment                                    = var.environment
  data_share_processor_name                      = each.key
  ingestor                                       = each.value.ingestor
  use_aws                                        = var.use_aws
  pure_gcp                                       = var.pure_gcp
  aws_region                                     = var.aws_region
  gcp_region                                     = var.gcp_region
  gcp_project                                    = var.gcp_project
  kubernetes_namespace                           = each.value.kubernetes_namespace
  certificate_domain                             = "${var.environment}.certificates.${var.manifest_domain}"
  ingestor_manifest_base_url                     = each.value.ingestor_manifest_base_url
  packet_decryption_key_kubernetes_secret        = each.value.packet_decryption_key_kubernetes_secret
  peer_share_processor_manifest_base_url         = each.value.peer_share_processor_manifest_base_url
  remote_bucket_writer_gcp_service_account_email = google_service_account.sum_part_bucket_writer.email
  portal_server_manifest_base_url                = each.value.portal_server_manifest_base_url
  is_first                                       = var.is_first
  intake_max_age                                 = var.intake_max_age
  aggregation_period                             = each.value.aggregation_period
  aggregation_grace_period                       = each.value.aggregation_grace_period
  kms_keyring                                    = var.use_aws ? "" : module.gke[0].kms_keyring
  pushgateway                                    = var.pushgateway
  workflow_manager_image                         = var.workflow_manager_image
  workflow_manager_version                       = var.workflow_manager_version
  facilitator_image                              = var.facilitator_image
  facilitator_version                            = var.facilitator_version
  container_registry                             = var.container_registry
  min_intake_worker_count                        = each.value.min_intake_worker_count
  max_intake_worker_count                        = each.value.max_intake_worker_count
  min_aggregate_worker_count                     = each.value.min_aggregate_worker_count
  max_aggregate_worker_count                     = each.value.max_aggregate_worker_count
  eks_oidc_provider                              = var.use_aws ? module.eks[0].oidc_provider : { url = "", arn = "" }
  gcp_workload_identity_pool_provider            = local.gcp_workload_identity_pool_provider
}

# The portal owns two sum part buckets (one for each data share processor) and
# the one for this data share processor gets configured by the portal operator
# to permit writes from this GCP service account, whose email the portal
# operator discovers in our global manifest. We use a GCP SA to write sum parts
# even if our data share processor runs on AWS.
resource "google_service_account" "sum_part_bucket_writer" {
  account_id   = "prio-${var.environment}-sum-writer"
  display_name = "prio-${var.environment}-sum-part-bucket-writer"
}

# If running in GCP, permit the service accounts for all the data share
# processors to request access and identity tokens allowing them to impersonate
# the sum part bucket writer.
resource "google_service_account_iam_binding" "data_share_processors_to_sum_part_bucket_writer_token_creator" {
  count              = var.use_aws ? 0 : 1
  service_account_id = google_service_account.sum_part_bucket_writer.name
  role               = "roles/iam.serviceAccountTokenCreator"
  members            = [for v in module.data_share_processors : "serviceAccount:${v.gcp_service_account_email}"]
}

# GCP services we must enable to use Workload Identity Pool
resource "google_project_service" "sts" {
  count   = var.use_aws ? 1 : 0
  service = "sts.googleapis.com"
}

resource "google_project_service" "iamcredentials" {
  count   = var.use_aws ? 1 : 0
  service = "iamcredentials.googleapis.com"
}

# If running EKS, we must create a Workload Identity Pool and Workload Identity
# Pool Provider to federate accounts.google.com with sts.amazonaws.com so that
# our data share processor AWS IAM roles will be able to impersonate the sum
# part bucket writer GCP service account.
resource "google_iam_workload_identity_pool" "aws_identity_federation" {
  count                     = var.use_aws ? 1 : 0
  provider                  = google-beta
  workload_identity_pool_id = "aws-identity-federation"
}

# A Workload Identity Pool *Provider* goes with the Workload Identity Pool and
# is bound to our AWS account ID by its numeric identifier. We don't specify any
# additional conditions or policies here, and instead use a GCP SA IAM binding
# on the sum part bucket writer.
resource "google_iam_workload_identity_pool_provider" "aws_identity_federation" {
  count                              = var.use_aws ? 1 : 0
  provider                           = google-beta
  workload_identity_pool_provider_id = "aws-identity-federation"
  workload_identity_pool_id          = google_iam_workload_identity_pool.aws_identity_federation[0].workload_identity_pool_id
  aws {
    account_id = data.aws_caller_identity.current.account_id
  }
}

resource "google_service_account_iam_binding" "data_share_processors_to_sum_part_bucket_writer_workload_identity_user" {
  count              = var.use_aws ? 1 : 0
  service_account_id = google_service_account.sum_part_bucket_writer.name
  role               = "roles/iam.workloadIdentityUser"
  # This principal allows an IAM role to impersonate the service account via the
  # Workload Identity Pool
  # https://cloud.google.com/iam/docs/access-resources-aws#impersonate
  members = [
    for v in module.data_share_processors : join("/", [
      "principalSet://iam.googleapis.com/projects",
      data.google_project.current.number,
      "locations/global/workloadIdentityPools",
      google_iam_workload_identity_pool.aws_identity_federation[0].workload_identity_pool_id,
      "attribute.aws_role/arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role",
      v.aws_iam_role.name,
    ])
  ]
}

locals {
  gcp_workload_identity_pool_provider = var.use_aws ? (
    join("/", [
      "//iam.googleapis.com/projects",
      data.google_project.current.number,
      "locations/global/workloadIdentityPools",
      google_iam_workload_identity_pool.aws_identity_federation[0].workload_identity_pool_id,
      "providers",
      google_iam_workload_identity_pool_provider.aws_identity_federation[0].workload_identity_pool_provider_id,
    ])
    ) : (
    ""
  )
}

module "fake_server_resources" {
  count                 = local.is_env_with_ingestor ? 1 : 0
  source                = "./modules/fake_server_resources"
  gcp_region            = var.gcp_region
  gcp_project           = var.gcp_project
  environment           = var.environment
  ingestor_pairs        = local.locality_ingestor_pairs
  own_manifest_base_url = local.manifest.base_url
  pushgateway           = var.pushgateway
  container_registry    = var.container_registry
  facilitator_image     = var.facilitator_image
  facilitator_version   = var.facilitator_version

  depends_on = [module.gke]
}

module "portal_server_resources" {
  count                        = local.deployment_has_ingestor ? 1 : 0
  source                       = "./modules/portal_server_resources"
  manifest_bucket              = local.manifest.bucket
  use_aws                      = var.use_aws
  gcp_region                   = var.gcp_region
  environment                  = var.environment
  sum_part_bucket_writer_email = google_service_account.sum_part_bucket_writer.email

  depends_on = [module.gke]
}

module "custom_metrics" {
  source            = "./modules/custom_metrics"
  environment       = var.environment
  use_aws           = var.use_aws
  eks_oidc_provider = var.use_aws ? module.eks[0].oidc_provider : { url = "", arn = "" }
}

# The monitoring module is disabled for now because it needs some AWS tweaks
# (wire up an EBS volume for metrics storage and forward SQS metrics into
# Prometheus). I'm commenting it out instead of putting in a count variable
# because this way we don't have to `terraform state mv` its resources into
# place when we turn it on.
module "monitoring" {
  source      = "./modules/monitoring"
  environment = var.environment
  use_aws     = var.use_aws
  gcp = {
    region  = var.gcp_region
    project = var.gcp_project
  }
  victorops_routing_key = var.victorops_routing_key
  aggregation_period    = var.default_aggregation_period
  eks_oidc_provider     = var.use_aws ? module.eks[0].oidc_provider : { url = "", arn = "" }

  prometheus_server_persistent_disk_size_gb = var.prometheus_server_persistent_disk_size_gb
}

output "manifest_bucket" {
  value = {
    bucket_url  = local.manifest.bucket_url
    aws_region  = local.manifest.aws_region
    aws_profile = local.manifest.aws_profile
  }
}

output "kubeconfig" {
  value = "Run this command to update your kubectl config: ${local.kubernetes_cluster.kubectl_command}"
}

output "specific_manifests" {
  value = { for v in module.data_share_processors : v.data_share_processor_name => {
    ingestor-name        = v.ingestor_name
    kubernetes-namespace = v.kubernetes_namespace
    certificate-fqdn     = v.certificate_fqdn
    specific-manifest    = v.specific_manifest
    }
  }
}

output "singleton_ingestor" {
  value = local.is_env_with_ingestor ? {
    aws_iam_entity              = module.fake_server_resources[0].aws_iam_entity
    gcp_service_account_id      = module.fake_server_resources[0].gcp_service_account_id
    gcp_service_account_email   = module.fake_server_resources[0].gcp_service_account_email
    tester_kubernetes_namespace = module.fake_server_resources[0].test_kubernetes_namespace
    batch_signing_key_name      = module.fake_server_resources[0].batch_signing_key_name
  } : {}
}

output "use_test_pha_decryption_key" {
  value = lookup(var.test_peer_environment, "env_without_ingestor", "") == var.environment
}

output "has_test_environment" {
  value = length(module.fake_server_resources) != 0
}
