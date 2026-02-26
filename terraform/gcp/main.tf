terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket  = "YOUR_GCP_GCS_TERRAFORM_STATE_BUCKET"
    prefix  = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.gcp_region
}
