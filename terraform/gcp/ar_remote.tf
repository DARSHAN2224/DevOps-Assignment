resource "google_artifact_registry_repository" "ghcr_remote" {
  location      = var.gcp_region
  repository_id = "ghcr-remote-${var.environment}"
  description   = "Remote repository for GHCR"
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    description = "GHCR remote repository"
    docker_repository {
      custom_repository {
        uri = "https://ghcr.io"
      }
    }
  }
}
