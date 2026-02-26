# DevOps Assignment Architecture & Infrastructure Documentation

## 1. Cloud & Region Selection

**AWS (Amazon Web Services)**
- **Region**: `us-east-1` (N. Virginia)
- **Justification**: It is the primary AWS region with the highest feature availability, largest availability zone count, and typically the lowest latency for US-East/Global general traffic due to its massive peering.
- **Tradeoffs**: It occasionally experiences higher defect rates compared to localized regions due to being the "testbed" for new AWS features, but for this application, the cost and feature maturity outweigh that risk.

**GCP (Google Cloud Platform)**
- **Region**: `us-central1` (Iowa)
- **Justification**: This is GCP's lowest-cost and most feature-complete region in North America. It offers a central geographical placement for balanced latency across the USA.
- **Tradeoffs**: Slightly higher latency for coastal users compared to edge regions (like `us-east4`), but the trade-off is significantly lower compute cost and guaranteed new feature rollouts.

---

## 2. Compute & Runtime Decisions

### AWS: Virtual Machines (EC2 via Auto Scaling Groups)
- **Choice**: EC2 Managed via Auto Scaling Groups (ASG) starting from Amazon Linux 2023 with Docker Compose via User-Data.
- **Justification**:
    - **Application Needs**: Next.js and FastAPI run cleanly in Docker. Running Docker natively on VMs with an ASG demonstrates traditional infrastructural paradigms.
    - **Operational Complexity**: Slightly higher than serverless, but extremely predictable.
    - **Scalability**: Scaling is handled automatically via ASG scaling policies based on CPU.
    - **Cost**: Good for predictable workloads. Can be heavily optimized using Reserved Instances or Spot instances.

### GCP: Managed Containers (Cloud Run)
- **Choice**: Google Cloud Run (Serverless).
- **Justification**:
    - **Application Needs**: The application is strictly stateless and HTTP-driven, making it the perfect candidate for Cloud Run.
    - **Operational Complexity**: Virtually zero infrastructure management. No OS patching, no node management.
    - **Scalability**: Can scale to zero (saving costs) and instantly spin up to thousands of instances during traffic spikes.
    - **Cost**: True pay-per-use model. Extremely cheap for low consistent loads and bursting traffic.

*(Note: Kubernetes was intentionally avoided as the application is simple (2 microservices) and the operational overhead of managing a cluster [upgrades, CNI, ingress controllers] severely outweighs the benefits for this scale).*

---

## 3. Networking & Traffic Flow

### AWS 
- **Public Components**: Application Load Balancer (ALB) and NAT Gateways sit in the Public Subnets.
- **Private Components**: EC2 instances reside strictly in Private Subnets with no public IPs.
- **Frontend ↔ Backend Communication**: 
    - The ALB listener rules act as a reverse proxy. 
    - `/*` routes to the Frontend Target Group (Port 3000).
    - `/api/*` routes to the Backend Target Group (Port 8000).
    - The EC2 SG only accepts traffic from the ALB SG, and the frontend container natively hits the ALB DNS to reach the backend, simulating cross-tier communication securely.

### GCP 
- **Traffic Routing**: Implemented a Global HTTP(S) External Load Balancer connected to Serverless Network Endpoint Groups (NEGs).
- **Frontend ↔ Backend Communication**:
    - URL Map routes `/api/*` requests to the Backend Cloud Run service and the rest to the Frontend Cloud Run service.
    - **Security**: The Cloud Run services have their ingress set to `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`, meaning they absolutely cannot be accessed directly via their default `run.app` URLs; traffic *must* flow through the Load Balancer and Google Cloud Armor.

---

## 4. Environment Separation
We structured Terraform via environment specific `/environments/{env}.tfvars`.

- **`dev`**: 
  - AWS: `t3.micro` instances. ASG min/max: 1/2.
  - GCP: Allows scaling to 0. Max instances: 2.
- **`staging`**: 
  - AWS: `t3.small` instances. ASG min/max: 2/4.
  - GCP: Max instances: 5. Matches Dev exactly in shape but slightly larger limits.
- **`prod`**: 
  - AWS: `m5.large` instances across multiple AZs. ASG min/max: 3/10. Termination protection explicitly enabled (simulated). 
  - GCP: Min instances: 2 (to eliminate cold starts). Max instances: 20.

---

## 5. Scalability & Availability

- **What scales automatically?** 
    - In AWS, the ASG scales the EC2 host count automatically. ALB scales automatically behind the scenes.
    - In GCP, Cloud Run instantly dynamically scales based on concurrency (configured to 80 requests per instance).
- **What does NOT?** 
    - The VPC subnets (CIDR ranges) are fixed. If we exhaust IPs, we cannot transparently scale. 
- **Traffic Spikes**: 
    - GCP handles spikes natively near-instantaneously (sub-second container spawns).
    - AWS handles spikes via step scaling. Wait times are ~1-2 minutes as the ASG detects EC2 CPU load, spins up a new instance, runs the User-Data script, and registers with the ALB.
- **Minimum Availability**: 
    - AWS runs across 2 Availability Zones minimum.
    - Cloud Run is natively regional.

---

## 6. Deployment Strategy (Infrastructure-Level)

- **What happens during a deployment**: 
    - Changes to code trigger GitHub Actions which build and push to GHCR.
    - Changes to Infrastructure trigger Terraform which updates the ASG Launch Template (AWS) or the Cloud Run revision (GCP).
- **Downtime expectations**: Zero downtime. 
    - AWS uses ASG Instance Refresh (Rolling Update). It drains old connections from ALB before termination.
    - GCP Cloud Run natively routes new traffic 100% to the new revision once healthy.
- **Rollback strategy**: Revert the Git commit, or replay the previous GitHub Action / Terraform Apply.
- **Failure handling**: If a deployment script fails (e.g. backend crash loop), the AWS Load Balancer Health Check will mark it unhealthy. Instance Refresh configuration pauses rollouts if instances fail health-checks, preventing a complete outage.

---

## 7. Infrastructure as Code & State Management

Used **Terraform** explicitly across the board.
- **State storage**: 
    - AWS: S3 Bucket configured with versioning.
    - GCP: Google Cloud Storage (GCS).
- **State isolation per environment**: State is heavily isolated per deployment environment by passing a dynamic `key` parameter to terraform initialization:
    - Example: `key = "dev/terraform.tfstate"` vs `key = "prod/terraform.tfstate"`
- **Locking**: 
    - AWS uses DynamoDB table locking to prevent concurrent mutation.
- **Recovery considerations**: S3/GCS Object Versioning is assumed to be enabled on the storage buckets so if a state file gets corrupted, a previous permutation can be pulled.

---

## 8. Security & Identity (Infra Perspective)

- **Deployment Identity**: GitHub Actions is configured to use OpenID Connect (OIDC) via AWS AssumeRole and GCP Workload Identity Federation instead of static, rotated long-lived credentials.
- **Human access control**: Uses AWS IAM/GCP IAM roles.
- **Secret Storage**: No hardcoded credentials. Passwords/Tokens are stored in GitHub Secrets.
- **Least-privilege**: 
    - EC2 runs an Instance Profile restricting it purely to SSM (AWS Systems Manager) for operator SSH access. It has no access to modify its environment.
    - GCP Cloud Run uses a dedicated, scoped `cloudrun-sa` rather than the permissive Compute Engine default service account.

---

## 9. Failure & Operational Thinking

**Smallest failure unit**:
- AWS: A single EC2 instance (which runs both backend/frontend). If either container crashes, the ALB health-checks `/api/health` and `/` sequentially fail, marking the *entire instance* dead. The ASG terminates it and provisions a new one. This ensures no split-brain deployments!
- GCP: A single Cloud Run container instance.

**What self-recovers**: 
- Virtual machine crashes (ASG self-heals).
- Spikes causing OOM (Cloud Run restarts immediately).

**Requires human intervention**: 
- VPC CIDR exhaustion.
- Infinite crash loops in code updates (requires developer to revert commit).

**Alerting Philosophy**: "Actionable alerts only". 
- 2 AM Page: "Prod Application Load Balancer returning > 5% 5xx errors".
- Slack Notification: "Dev instance rebooted".

---

## 10. Future Growth Scenario
*(Assume 10x traffic, new backend service, client demands stricter isolation, region-specific data)*

- **What infrastructure changes**: 
    - We would introduce a dedicated database (RDS/Cloud SQL) with read-replicas. 
    - We would split the AWS setup from running Docker-Compose on single instances to using AWS ECS or EKS for granular scaling of `frontend` independently from `backend`.
    - Region-specific data forces us to deploy the Terraform stack to another region (`eu-west-1`) and use Geo-Routing at the DNS layer (Route53).
- **What remains unchanged**: Terraform module structure (`environments` layout), OIDC security pipelines, and CI/CD philosophy.
- **Early decisions**: 
    - *Helpful*: Using the ALB/Global LB as ingress was brilliant because routing a new backend service just means adding an ALB rule for `/api/v2/*` pointing to a new target group.
    - *Painful*: The current AWS "User-Data Docker Compose" setup hurts because scaling frontend scaling independently from backend scaling isn't possible, wasting compute.

---

## "What We Did NOT Do"
1. **Did NOT use Kubernetes**: Setting up EKS/GKE for a 2-container app is an anti-pattern of over-engineering. It introduces severe operational tax without tangible benefit for this scale.
2. **Did NOT use statically exported Next.js**: While Next.js can be an S3/CloudFront static site, deploying it as a server on equal scaling plane to the backend acts as a better demonstration of complex cloud compute architectures.
3. **Did NOT put databases in Terraform**: The application didn't require state. Had it needed a DB, we would have provisioned managed services (RDS) rather than running PostgreSQL in Docker to avoid data-durability nightmares.
