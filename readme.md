# 🚀 DevSecOps E-Commerce Platform on AWS EKS

A production‑grade, highly available e‑commerce platform with a complete DevSecOps pipeline.  
Built with **Spring Boot** (backend), **React** (frontend), **MySQL** on RDS, deployed on **AWS EKS**.  
The pipeline integrates **Jenkins** for CI, **ArgoCD** for GitOps CD, **Terraform** for infrastructure, and **Prometheus/Grafana/ELK** for observability.

---

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Infrastructure Setup (Terraform)](#infrastructure-setup-terraform)
- [CI/CD Pipeline](#cicd-pipeline)
  - [Jenkins CI](#jenkins-ci)
  - [ArgoCD GitOps CD](#argocd-gitops-cd)
- [Deploying the Application](#deploying-the-application)
- [Blue‑Green Deployment](#blue‑green-deployment)
- [Monitoring & Logging](#monitoring--logging)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Conclusion](#conclusion)

---

## 🏗 Architecture Overview

![Architecture Diagram](docs/architecture.png) *(create a diagram or omit)*

- **AWS** – EKS (Kubernetes), RDS MySQL (Multi‑AZ + read replica), S3 (backups), IAM, ALB, Route53.
- **CI** – Jenkins pipeline with SonarQube, Trivy, OWASP, Docker build & push.
- **CD** – ArgoCD watches Git repository and syncs manifests to EKS.
- **Kubernetes** – Deployments with blue‑green strategy, HPA, Ingress (NGINX + ALB), Cert‑Manager.
- **Monitoring** – Prometheus & Grafana (metrics, alerts).
- **Logging** – ELK Stack (Elasticsearch, Logstash, Kibana).
- **Backup** – Velero + RDS snapshots.

---

## ✅ Prerequisites

- **AWS account** with appropriate permissions (EC2, EKS, RDS, S3, IAM).
- **AWS CLI** installed and configured (`aws configure`).
- **Terraform** (≥1.3), **kubectl**, **eksctl**, **Helm** installed locally.
- **GitHub** repository to store code and manifests.
- **Docker Hub** account (or ECR) for image registry.
- **Domain name** (optional) for HTTPS and ingress.

---

## 🌍 Infrastructure Setup (Terraform)

All AWS resources are defined as code using Terraform.  
The configuration creates:

- VPC with public/private subnets across 3 AZs, NAT gateways.
- EKS cluster with managed node groups (t3.medium, auto‑scale 2–6 nodes).
- RDS MySQL primary (Multi‑AZ) + read replica.
- S3 bucket for backups (Velero).
- IAM roles and policies for EKS and service accounts.

### Steps

1. **Clone the repository**  
   ```bash
   git clone https://github.com/your-org/ecommerce-devsecops.git
   cd ecommerce-devsecops/terraform
   ```

2. **Create `terraform.tfvars`** with your values (especially `db_password`).  
   Example:
   ```hcl
   aws_region           = "eu-west-1"
   project_name         = "ecommerce"
   environment          = "prod"
   db_password          = "YourSuperSecretPassword123!"
   ```

3. **Initialize and apply**  
   ```bash
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

4. **Configure kubectl**  
   ```bash
   aws eks update-kubeconfig --region eu-west-1 --name ecommerce-cluster
   kubectl get nodes   # verify
   ```

---

## 🔄 CI/CD Pipeline

### Jenkins CI

The Jenkins pipeline (`Jenkinsfile`) automates:

- Code checkout
- Unit tests
- SonarQube analysis & quality gate
- OWASP dependency check
- Trivy filesystem scan
- Docker build (multi‑stage) for backend & frontend
- Trivy image scan
- Push images to Docker Hub
- Update Kubernetes manifests with the new image tag
- Commit and push changes back to Git

#### Setup Jenkins

1. **Install Jenkins** on a dedicated server (e.g., t2.large Ubuntu).  
   Follow the official guide or use the commands in the main documentation.

2. **Install required plugins**  
   - Docker Pipeline
   - SonarQube Scanner
   - Dependency‑Check
   - Git
   - Pipeline: Stage View
   - Email Extension
   - Kubernetes CLI (optional)

3. **Configure credentials** in Jenkins  
   - `github-creds` – GitHub username + personal access token  
   - `dockerHub` – Docker Hub username + password

4. **Configure SonarQube**  
   - Run SonarQube as a Docker container (or install)  
   - Create a webhook in SonarQube pointing to Jenkins (`http://<jenkins-ip>:8080/sonarqube-webhook/`)  
   - Add SonarQube server in **Manage Jenkins → Configure System**  
   - Install SonarScanner tool in **Global Tool Configuration**

5. **Create a pipeline job**  
   - New Item → Pipeline → "ecommerce-pipeline"  
   - Definition: Pipeline script from SCM  
   - SCM: Git, repository URL, credentials, branch `main`  
   - Script Path: `jenkins/Jenkinsfile`

6. **Run the pipeline**  
   Trigger a build with parameters `IMAGE_TAG` (e.g., `v1.0`) and `DEPLOY_SLOT` (`blue` or `green`).  
   The pipeline will push images and update the manifests in Git.

### ArgoCD GitOps CD

ArgoCD continuously syncs the Kubernetes manifests from the Git repository to the EKS cluster.

1. **Install ArgoCD** on the EKS cluster  
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

2. **Expose the ArgoCD server** (e.g., via LoadBalancer)  
   ```bash
   kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"LoadBalancer"}}'
   ```

3. **Get the initial admin password**  
   ```bash
   kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
   ```

4. **Add your Git repository** to ArgoCD  
   ```bash
   argocd login <argocd-server-ip> --username admin
   argocd repo add https://github.com/your-org/ecommerce-devsecops.git --username your-username --password your-token
   ```

5. **Create the Application**  
   Apply the `argocd/application.yml` manifest:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: ecommerce-app
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: https://github.com/your-org/ecommerce-devsecops.git
       targetRevision: main
       path: kubernetes/
     destination:
       server: https://kubernetes.default.svc
       namespace: ecommerce-prod
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
   ```
   ```bash
   kubectl apply -f argocd/application.yml
   ```

ArgoCD will now automatically sync any changes in the `kubernetes/` directory to the cluster.

---

## 🚀 Deploying the Application

After infrastructure and CI/CD are set up, the application is deployed as follows:

1. **Developer pushes code** to GitHub.
2. **Jenkins pipeline** triggers, builds images, updates manifests, and commits back.
3. **ArgoCD** detects the change and syncs the new manifests to EKS.
4. **Kubernetes** rolls out new pods (blue or green slot).

### Manual Deployment (if needed)

1. **Create the namespace**  
   ```bash
   kubectl apply -f kubernetes/namespace.yml
   ```

2. **Apply ConfigMap and Secrets**  
   ```bash
   kubectl apply -f kubernetes/backend/configmap.yml
   kubectl apply -f kubernetes/backend/secrets.yml
   ```

3. **Deploy backend and frontend**  
   ```bash
   kubectl apply -f kubernetes/backend/deployment-blue.yml
   kubectl apply -f kubernetes/backend/deployment-green.yml
   kubectl apply -f kubernetes/frontend/deployment-blue.yml
   kubectl apply -f kubernetes/frontend/deployment-green.yml
   ```

4. **Create services**  
   ```bash
   kubectl apply -f kubernetes/backend/service.yml
   kubectl apply -f kubernetes/frontend/service.yml
   ```

5. **Set up Ingress**  
   Install NGINX Ingress Controller and Cert‑Manager, then apply the ingress:
   ```bash
   kubectl apply -f kubernetes/ingress/ingress.yml
   ```

6. **Configure HPA**  
   ```bash
   kubectl apply -f kubernetes/backend/hpa.yml
   ```

7. **Verify**  
   ```bash
   kubectl get pods -n ecommerce-prod
   kubectl get ingress -n ecommerce-prod   # get the LoadBalancer address
   ```

---

## 🔁 Blue‑Green Deployment

The platform uses a blue‑green deployment strategy for zero‑downtime updates.

- **Blue** – current live version (selector `slot: blue`).
- **Green** – new version (selector `slot: green`) deployed alongside.

Traffic is switched by patching the service selector.

### Switch Traffic

```bash
# Switch backend to green
kubectl patch svc backend-service -n ecommerce-prod -p '{"spec":{"selector":{"slot":"green"}}}'

# Switch frontend to green
kubectl patch svc frontend-service -n ecommerce-prod -p '{"spec":{"selector":{"slot":"green"}}}'
```

To rollback, simply change `slot` back to `blue`.

### Blue‑Green Script

A helper script is provided at `scripts/blue-green-switch.sh`:

```bash
#!/bin/bash
CURRENT=$(kubectl get svc backend-service -n ecommerce-prod -o jsonpath='{.spec.selector.slot}')
echo "Current active slot: $CURRENT"
if [ "$CURRENT" == "blue" ]; then NEW_SLOT="green"; else NEW_SLOT="blue"; fi
kubectl patch svc backend-service -n ecommerce-prod -p "{\"spec\":{\"selector\":{\"slot\":\"$NEW_SLOT\"}}}"
kubectl patch svc frontend-service -n ecommerce-prod -p "{\"spec\":{\"selector\":{\"slot\":\"$NEW_SLOT\"}}}"
echo "Traffic now routed to slot: $NEW_SLOT"
```

---

## 📊 Monitoring & Logging

### Prometheus & Grafana

1. **Install kube‑prometheus‑stack** via Helm  
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   helm install prometheus prometheus-community/kube-prometheus-stack \
     --namespace monitoring --create-namespace \
     --set grafana.adminPassword='SecureGrafanaPass123'
   ```

2. **Access Grafana**  
   ```bash
   kubectl port-forward -n monitoring service/prometheus-grafana 3000:80
   ```
   Then open `http://localhost:3000` (admin / the password you set).

3. **ServiceMonitor for backend**  
   Apply `kubernetes/monitoring/service-monitor.yml` to let Prometheus scrape Spring Boot metrics.

### ELK Stack (Elasticsearch, Logstash, Kibana)

1. **Install via Helm**  
   ```bash
   helm repo add elastic https://helm.elastic.co
   helm install elasticsearch elastic/elasticsearch --namespace logging --create-namespace
   helm install kibana elastic/kibana --namespace logging
   helm install logstash elastic/logstash --namespace logging
   helm install filebeat elastic/filebeat --namespace logging --set daemonset.enabled=true
   ```

2. **Access Kibana**  
   ```bash
   kubectl port-forward -n logging service/kibana-kibana 5601:5601
   ```
   Create index pattern `filebeat-*` with time field `@timestamp`.

---

## 🔒 Security

- **IAM** – Fine‑grained policies for CI/CD user and EKS node roles.
- **RBAC** – Kubernetes roles and bindings limit permissions (e.g., ArgoCD).
- **Network Policies** – Restrict pod‑to‑pod communication (e.g., only Ingress to backend).
- **Secrets** – Base64‑encoded in Git (for demo). For production, use **External Secrets Operator** with AWS Secrets Manager.
- **Image Scanning** – Trivy scans both filesystem and container images during CI.
- **Code Quality** – SonarQube gates the pipeline.
- **HTTPS** – Cert‑Manager + Let's Encrypt provide TLS certificates.

---

## 🛠 Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Pods in `CrashLoopBackOff` | Application error or missing env vars | `kubectl logs <pod> -n ecommerce-prod` |
| `ImagePullBackOff` | Wrong image name or missing credentials | Check image tag and `imagePullSecrets` |
| Service unreachable | Wrong selector labels | `kubectl get endpoints -n ecommerce-prod` |
| HPA not scaling | Metrics Server not installed | Install Metrics Server |
| ArgoCD out of sync | Manifest change not detected | `argocd app sync ecommerce-app` |
| TLS cert not issued | Cert‑Manager or ACME challenge failed | `kubectl describe certificaterequest` |
| 503 from Ingress | No healthy backend pods | Check backend pod status and endpoints |

**Useful commands:**
```bash
kubectl describe pod <pod> -n ecommerce-prod
kubectl logs -f <pod> -n ecommerce-prod
kubectl exec -it <pod> -n ecommerce-prod -- sh
kubectl get events -n ecommerce-prod --sort-by='.lastTimestamp'
```

---

## 🎯 Conclusion

You have successfully deployed a fully automated, secure, and scalable e‑commerce platform on AWS EKS using a modern DevSecOps approach. The CI/CD pipeline ensures rapid and reliable delivery, while monitoring and logging provide complete observability. The blue‑green deployment strategy guarantees zero‑downtime updates.

For further enhancements, consider:

- Integrating **AWS Secrets Manager** for sensitive data.
- Adding **canary deployments** with Flagger.
- Implementing **chaos engineering** experiments.
- Extending monitoring with custom dashboards and alerts.

---

**Happy Coding!** 🚀