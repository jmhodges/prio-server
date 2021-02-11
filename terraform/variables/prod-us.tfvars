environment     = "prod-us"
gcp_region      = "us-west1"
gcp_project     = "prio-prod-us"
machine_type    = "e2-standard-8"
localities      = ["ta-ta", "us-ct", "us-md", "us-va", "us-wa"]
aws_region      = "us-west-1"
manifest_domain = "isrg-prio.org"
managed_dns_zone = {
  name        = "manifests"
  gcp_project = "prio-bringup-290620"
}
ingestors = {
  apple = {
    manifest_base_url = "exposure-notification.apple.com/manifest"
    localities = {
      ta-ta = {
        intake_worker_count    = 1
        aggregate_worker_count = 1
      }
      us-ct = {
        intake_worker_count    = 1
        aggregate_worker_count = 1
      }
      us-md = {
        intake_worker_count    = 1
        aggregate_worker_count = 1
      }
      us-va = {
        intake_worker_count    = 1
        aggregate_worker_count = 1
      }
      us-wa = {
        intake_worker_count    = 1
        aggregate_worker_count = 1
      }
    }
  }
  g-enpa = {
    manifest_base_url = "storage.googleapis.com/prio-manifests"
    localities = {
      ta-ta = {
        intake_worker_count    = 1
        aggregate_worker_count = 1
      }
      us-ct = {
        intake_worker_count    = 1
        aggregate_worker_count = 1
      }
      us-md = {
        intake_worker_count    = 1
        aggregate_worker_count = 1
      }
      us-va = {
        intake_worker_count    = 1
        aggregate_worker_count = 1
      }
      us-wa = {
        intake_worker_count    = 1
        aggregate_worker_count = 1
      }
    }
  }
}
peer_share_processor_manifest_base_url    = "en-analytics.cancer.gov"
portal_server_manifest_base_url           = "manifest.enpa-pha.io"
is_first                                  = false
use_aws                                   = false
aggregation_period                        = "8h"
aggregation_grace_period                  = "4h"
workflow_manager_version                  = "0.6.5"
facilitator_version                       = "0.6.5"
pushgateway                               = "prometheus-pushgateway.monitoring:9091"
prometheus_server_persistent_disk_size_gb = 1000
victorops_routing_key                     = "prio-prod-us"
