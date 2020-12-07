environment     = "prod-us"
gcp_region      = "us-west1"
gcp_project     = "prio-prod-us"
machine_type    = "e2-standard-8"
localities      = []
aws_region      = "us-west-1"
manifest_domain = "isrg-prio.org"
managed_dns_zone = {
  name        = "manifests"
  gcp_project = "prio-bringup-290620"
}
ingestors = {
  apple  = "exposure-notification.apple.com/manifest"
  g-enpa = "www.gstatic.com/prio-manifests"
}
peer_share_processor_manifest_base_url = "en-analytics.cancer.gov"
portal_server_manifest_base_url        = "manifest.enpa-pha.io"
is_first                               = false
use_aws                                = false
aggregation_period                     = "8h"
aggregation_grace_period               = "4h"
