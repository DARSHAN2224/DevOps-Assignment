output "load_balancer_ip" {
  description = "The global IP address of the External Load Balancer"
  value       = google_compute_global_address.default.address
}

output "frontend_cloud_run_url" {
  description = "The direct URL of the Frontend Cloud Run service (Internal only via LB)"
  value       = google_cloud_run_v2_service.frontend.uri
}

output "backend_cloud_run_url" {
  description = "The direct URL of the Backend Cloud Run service (Internal only via LB)"
  value       = google_cloud_run_v2_service.backend.uri
}
