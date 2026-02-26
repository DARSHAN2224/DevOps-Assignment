terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket  = "tf-state-devops-488609"
    prefix  = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.gcp_region
}
