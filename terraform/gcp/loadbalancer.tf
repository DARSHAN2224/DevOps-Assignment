# Serverless NEGs
resource "google_compute_region_network_endpoint_group" "frontend_neg" {
  name                  = "frontend-neg-${var.environment}"
  network_endpoint_type = "SERVERLESS"
  region                = var.gcp_region
  cloud_run {
    service = google_cloud_run_v2_service.frontend.name
  }
}

resource "google_compute_region_network_endpoint_group" "backend_neg" {
  name                  = "backend-neg-${var.environment}"
  network_endpoint_type = "SERVERLESS"
  region                = var.gcp_region
  cloud_run {
    service = google_cloud_run_v2_service.backend.name
  }
}

# Backend Services for the Load Balancer
resource "google_compute_backend_service" "frontend_backend" {
  name        = "frontend-backend-${var.environment}"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_region_network_endpoint_group.frontend_neg.id
  }
}

resource "google_compute_backend_service" "backend_backend" {
  name        = "api-backend-${var.environment}"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_region_network_endpoint_group.backend_neg.id
  }
}

# URL Map
resource "google_compute_url_map" "default" {
  name            = "urlmap-${var.environment}"
  default_service = google_compute_backend_service.frontend_backend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.frontend_backend.id

    path_rule {
      paths   = ["/api", "/api/*"]
      service = google_compute_backend_service.backend_backend.id
    }
  }
}

# HTTP Proxy
resource "google_compute_target_http_proxy" "default" {
  name    = "http-proxy-${var.environment}"
  url_map = google_compute_url_map.default.id
}

# Global Forwarding Rule (Public IP)
resource "google_compute_global_address" "default" {
  name = "global-address-${var.environment}"
}

resource "google_compute_global_forwarding_rule" "default" {
  name                  = "forwarding-rule-${var.environment}"
  target                = google_compute_target_http_proxy.default.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.default.address
}
