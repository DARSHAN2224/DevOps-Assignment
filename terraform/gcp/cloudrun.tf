locals {
  service_account_id = "cloudrun-sa-${var.environment}"
}

resource "google_service_account" "cloudrun" {
  account_id   = local.service_account_id
  display_name = "Cloud Run Service Account for ${var.environment}"
}

# Backend Service
resource "google_cloud_run_v2_service" "backend" {
  name     = "backend-${var.environment}"
  location = var.gcp_region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = google_service_account.cloudrun.email
    max_instance_request_concurrency = var.concurrency

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello" # Placeholder until first deploy
      ports {
        container_port = 8000
      }
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image]
  }
}

# Frontend Service
resource "google_cloud_run_v2_service" "frontend" {
  name     = "frontend-${var.environment}"
  location = var.gcp_region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = google_service_account.cloudrun.email
    max_instance_request_concurrency = var.concurrency

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello" # Placeholder until first deploy
      ports {
        container_port = 3000
      }
      env {
        name  = "NEXT_PUBLIC_BACKEND_URL"
        value = "/api"
      }
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image]
  }
}

# Allow unauthenticated traffic via IAM (but only accessible through Load Balancer due to ingress setting)
resource "google_cloud_run_service_iam_binding" "backend_invoker" {
  location = google_cloud_run_v2_service.backend.location
  service  = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  members  = ["allUsers"]
}

resource "google_cloud_run_service_iam_binding" "frontend_invoker" {
  location = google_cloud_run_v2_service.frontend.location
  service  = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  members  = ["allUsers"]
}
