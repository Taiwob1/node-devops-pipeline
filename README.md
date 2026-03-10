Node.js Production DevOps Pipeline
https://mydevopsapp.live
What This Project Does
This project takes a simple Node.js API and makes it production-ready from the ground up. The application exposes three endpoints, runs inside a Docker container on AWS ECS Fargate, sits behind an Application Load Balancer with HTTPS, uses Redis (AWS ElastiCache) for data persistence, and gets deployed automatically every time code is pushed to the main branch.

The entire infrastructure — VPC, subnets, security groups, load balancer, ECS cluster, ElastiCache, SSL certificate, DNS — is defined as code in Terraform and provisioned automatically by the pipeline.

Application Endpoints
Once the app is running (locally or in production), you can hit these endpoints:

Method	Endpoint	Description
GET	/health	Returns { status: "healthy" }
GET	/status	Returns current server time
POST	/process	Accepts JSON body, stores in Redis

Running the Application Locally
You will need Docker and Docker Compose installed. Clone the repository and start everything with a single command:

git clone https://github.com/Taiwob1/node-devops-pipeline.git
cd node-devops-pipeline
docker-compose up --build

This starts two containers — the Node.js app on port 3000 and a Redis instance. The app connects to Redis automatically using the REDIS_HOST environment variable set in the compose file.

Once running, test it:

curl http://localhost:3000/health
curl http://localhost:3000/status
curl -X POST http://localhost:3000/process -H "Content-Type: application/json" -d '{"message": "hello world"}'

To stop everything:
docker-compose down

How to Access the Live App
The application is deployed and accessible at:

•	https://mydevopsapp.live/health
•	https://mydevopsapp.live/status
•	https://mydevopsapp.live/process  (POST)

HTTPS is handled by an AWS ACM certificate validated via Route 53 DNS.

How to Deploy
Deployment is fully automated. Any push to the main branch triggers the GitHub Actions pipeline, which:

1.	Installs dependencies and runs tests
2.	Builds the Docker image and pushes it to DockerHub
3.	Authenticates to AWS using OIDC — no static credentials
4.	Runs terraform plan and terraform apply to update infrastructure

The deploy job is configured with a production environment in GitHub, which can be configured to require manual approval before applying changes.

To trigger a deployment manually, simply push to main:

git add .
git commit -m "your change"
git push origin main

First-Time Setup
If you are setting this up from scratch, you will need:

•	An S3 bucket for Terraform state (my-terraform-state-bucket44)
•	A DynamoDB table for state locking (terraform-lock)
•	An IAM role for GitHub Actions OIDC (githubactionsrole) with a trust policy pointing to your GitHub repo
•	A secret in AWS Secrets Manager at dockerhub/credentials with username and password keys
•	A DockerHub account with a Personal Access Token that has read/write permissions
•	Your domain registered with nameservers pointing to AWS Route 53

Project Structure
app/
    server.js          Main application
    test.js            Basic test
    package.json
docker/
    Dockerfile         Multi-stage build
docker-compose.yml     Local development setup
terraform/
    provider.tf        AWS provider
    backend.tf         S3 remote state
    vpc.tf             VPC, subnets, internet gateway
    security.tf        Security groups
    alb.tf             Load balancer, listeners, ACM, Route 53
    ecs.tf             ECS cluster, task definition, service
    elasticache.tf     Redis cluster
    outputs.tf         ALB DNS, Redis endpoint
.github/workflows/
    ci-cd.yml          GitHub Actions pipeline

Infrastructure Overview
All infrastructure lives in AWS us-east-1 and is provisioned by Terraform.

Networking — A custom VPC (10.0.0.0/16) with two public subnets across two availability zones (us-east-1a and us-east-1b). An Internet Gateway and route table are attached to both subnets to allow outbound internet access.
Compute — The application runs on AWS ECS Fargate, which means no EC2 instances to manage. The ECS service maintains two running tasks at all times across both subnets for high availability. Fargate handles the underlying infrastructure automatically.
Load Balancer — An Application Load Balancer distributes traffic across the two ECS tasks. It listens on both port 80 (HTTP) and port 443 (HTTPS). Health checks hit the /health endpoint every 30 seconds.
Database — AWS ElastiCache runs a single Redis 7 node (cache.t3.micro) in a private subnet group. Only the ECS security group can reach it on port 6379.
DNS and SSL — The domain mydevopsapp.live is managed in Route 53. An ACM certificate handles HTTPS, validated automatically via DNS. A wildcard certificate covers both the root domain and all subdomains.
State Management — Terraform state is stored remotely in S3 with DynamoDB locking to prevent concurrent apply operations.

Key Security Decisions
No static AWS credentials — The GitHub Actions pipeline authenticates to AWS using OIDC (OpenID Connect). GitHub generates a short-lived token for each workflow run, which is exchanged for temporary AWS credentials via sts:AssumeRoleWithWebIdentity. No access keys are stored anywhere.
Secrets via AWS Secrets Manager — DockerHub credentials are stored in AWS Secrets Manager and fetched at runtime by the pipeline. They are never hardcoded in the workflow file or repository.
Non-root container — The Dockerfile creates a dedicated appuser in a dedicated appgroup and switches to that user before starting the application. The container never runs as root.
Least-privilege security groups — The ALB security group only accepts inbound traffic on ports 80 and 443. The ECS security group only accepts inbound traffic on port 3000 from the ALB security group. The Redis security group only accepts traffic on port 6379 from the ECS security group. Each layer can only talk to the layer directly below it.
Multi-stage Docker build — The Dockerfile uses a two-stage build. The first stage installs dependencies and compiles the app. The second stage copies only the built output into a clean runtime image, keeping the final image small and free of build tools.

CI/CD Pipeline Details
The pipeline is split into two jobs: build and deploy.

The build job runs on every push and pull request to main. It installs dependencies, runs tests, builds the Docker image using the multi-stage Dockerfile, and pushes it to DockerHub. AWS credentials are obtained via OIDC to pull the DockerHub token from Secrets Manager.

The deploy job only runs after build succeeds, and only on pushes to main (not pull requests). It uses the GitHub production environment, which can be configured to require a manual approval gate before Terraform applies any changes. This gives you control over what actually reaches production.

Terraform uses an S3 backend with DynamoDB locking so that only one pipeline run can modify infrastructure at a time.

Observability
Application logs are shipped to AWS CloudWatch under the log group /ecs/node-app with a 7-day retention period. Each container task writes logs with the ecs prefix, making it easy to filter by task in the CloudWatch console.

The /health endpoint is used by both the ALB health check and ECS service health monitoring. If a task stops responding on that endpoint, ECS automatically replaces it and the ALB stops routing traffic to it until it recovers.

Deployment Strategy
The ECS service uses a rolling deployment strategy. When a new task definition is deployed, ECS starts new tasks before stopping old ones. The service is configured with deployment_minimum_healthy_percent = 100 and deployment_maximum_percent = 200, which means during a deployment, ECS runs up to 4 tasks temporarily — double the desired count of 2 — before draining and stopping the old ones. This ensures zero downtime during deployments.

