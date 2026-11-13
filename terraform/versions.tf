terraform {
  required_version = ">= 1.6"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }

  # Local state by default. For team use, switch to a remote backend, e.g. an
  # OVHcloud Object Storage bucket through the S3 backend.
}
