# Complete Guide to Deploying Your DevOps Assignment

This guide will walk you through exactly how to set up your AWS and GCP accounts, authenticate your local machine, and run the Terraform code we generated to deploy the infrastructure.

---

## 1. Prerequisites (For Your Local Machine)

Before starting, ensure you have the following installed on your computer.

### Required Software
1. **Terraform**: [Download & Install Terraform](https://developer.hashicorp.com/terraform/downloads)
2. **AWS CLI**: [Download & Install AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
3. **Google Cloud SDK (gcloud)**: [Download & Install gcloud CLI](https://cloud.google.com/sdk/docs/install)
4. **Git**: (You should already have this)

Verify installations by running these commands in your terminal:
```bash
terraform -version
aws --version
gcloud --version
```

---

## 2. Deploying First: Your Docker Images

Before the infrastructure can run, it needs the application code! We set up GitHub Actions to handle this automatically:

1. Push the code to your GitHub fork:
   ```bash
   git add .
   git commit -m "feat: complete infrastructure code"
   git push origin main
   ```
2. Go to your GitHub repository -> Click on **Actions** tab.
3. You should see a workflow titled **Build and Push Docker Images** running.
4. Wait for it to turn green ✅. This creates your containers at `ghcr.io/darshan2224/devops-assignment/frontend:latest` and `/backend`.
5. **CRITICAL STEP**: By default, GitHub packages might be private. 
   - Go to your personal GitHub Profile -> **Packages**
   - Click on the `devops-assignment/frontend` package.
   - Click **Package Settings** -> **Change package visibility** -> Select **Public**.
   - Repeat for the `devops-assignment/backend` package.
   *(If you don't do this, AWS/GCP cannot pull the images without credentials).*

---

## 3. Deploying to AWS ☁️

### Step 3.1: Authenticate AWS
1. Log into your AWS Console in the browser.
2. Go to **IAM** -> **Users** -> Create a user (or use your existing one).
3. Ensure the user has `AdministratorAccess` (since we are creating VPCs, IAM roles, ALBs, etc).
4. Go to the user's **Security credentials** tab and create an **Access Key**.
5. Open your terminal and run:
   ```bash
   aws configure
   ```
   Paste the Access Key, Secret Key, and set default region to `us-east-1`. Output format: `json`.

### Step 3.2: Prepare AWS Terraform State
State must be safely stored in an S3 bucket with a DynamoDB lock table.
1. Run this command to create the bucket (replace `YOUR-UNIQUE-NAME` with something random like `darshan-tf-state-123`):
   ```bash
   aws s3api create-bucket --bucket darshan-devops-tf-state-123 --region us-east-1
   ```
2. Run this command to create the lock table:
   ```bash
   aws dynamodb create-table --table-name darshan-devops-tf-lock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region us-east-1
   ```
3. Open `terraform/aws/main.tf` in your code editor.
4. Update lines 10 and 14 with the names you just created:
   ```hcl
   bucket         = "darshan-devops-tf-state-123"
   dynamodb_table = "darshan-devops-tf-lock"
   ```

### Step 3.3: Deploy AWS Infrastructure!
Run the following commands in your terminal:
```bash
cd terraform/aws

# Initialize Terraform (downloads AWS plugins and connects to S3 state)
terraform init

# Review what Terraform will create for the 'dev' environment
terraform plan -var-file="environments/dev.tfvars"

# Apply the changes (type 'yes' when prompted)
terraform apply -var-file="environments/dev.tfvars"
```
**Wait ~5-7 minutes.**
Once it finishes, it will print an output like:
`alb_dns_name = "alb-dev-12345.us-east-1.elb.amazonaws.com"`.
This is your live AWS link!

---

## 4. Deploying to Google Cloud (GCP) ☁️

### Step 4.1: Authenticate GCP
1. Log into your Google Cloud Console.
2. Create a new Google Cloud Project. Note down the **Project ID** (e.g., `devops-assignment-415522`).
3. You **must enable billing** for this project (Cloud Run requires it).
4. Run these terminal commands to authenticate your local machine:
   ```bash
   gcloud auth login
   gcloud config set project devops-488609

   gcloud auth application-default login
   ```

### Step 4.2: Enable GCP APIs
Terraform needs permission to create resources. Run this in your terminal:
```bash
gcloud services enable compute.googleapis.com run.googleapis.com iam.googleapis.com
```

### Step 4.3: Prepare GCP Terraform State
GCP state is stored in a Google Cloud Storage (GCS) bucket.
1. Create a globally unique bucket (replace `YOUR-UNIQUE-NAME` like `darshan-gcp-tf-state-123`):
   ```bash
   gcloud storage buckets create gs://darshan-gcp-tf-state-123 --location=us-central1
   ```
2. Open `terraform/gcp/main.tf` in your code editor.
3. Update line 10 with your bucket name:
   ```hcl
   bucket  = "darshan-gcp-tf-state-123"
   ```
4. Open `terraform/gcp/environments/dev.tfvars` and update the `project_id` variable with your actual GCP Project ID.

### Step 4.4: Build and Push Images to GCP Artifact Registry
Google Cloud requires images to be stored in its native Artifact Registry. Run these commands from the root directory of the project:
```bash
# 1. Create a Docker repository in your GCP project
gcloud artifacts repositories create app-repo --repository-format=docker --location=us-central1

# 2. Configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# 3. Build and Push the Backend
docker build -t us-central1-docker.pkg.dev/devops-488609/app-repo/backend:latest ./backend
docker push us-central1-docker.pkg.dev/devops-488609/app-repo/backend:latest

# 4. Build and Push the Frontend
docker build -t us-central1-docker.pkg.dev/devops-488609/app-repo/frontend:latest ./frontend
docker push us-central1-docker.pkg.dev/devops-488609/app-repo/frontend:latest
```

### Step 4.5: Deploy GCP Infrastructure!
Run the following commands:
```bash
# Go up to base directory, then into GCP
cd ../../terraform/gcp

# Initialize Terraform
terraform init

# Review the plan
terraform plan -var-file="environments/dev.tfvars"

# Apply the changes (type 'yes' when prompted)
terraform apply -var-file="environments/dev.tfvars"
```
**Wait ~3-5 minutes.**
Once it finishes, it will print outputs like:
`load_balancer_ip = "34.120.x.x"`
This is your live GCP link!

---

## 5. Cleaning Up (Crucial Step to Avoid Bills!)

Once you have recorded your demo video and submitted your links, you **MUST** destroy the infrastructure so AWS and GCP stop charging your credit card.

**To destroy AWS:**
```bash
cd terraform/aws
terraform destroy -var-file="environments/dev.tfvars"
```

**To destroy GCP:**
```bash
cd terraform/gcp
terraform destroy -var-file="environments/dev.tfvars"
```
*(Alternatively, in GCP, you can just delete the whole Project in the console to wipe everything instantly).*
