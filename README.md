# 🚀 GitOps Project — UN Enterprise Quantitative Trading Website

![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-blue?style=flat-square&logo=argo)
![CI/CD](https://img.shields.io/badge/CI%2FCD-Jenkins-red?style=flat-square&logo=jenkins)
![Docker](https://img.shields.io/badge/Container-Docker-2496ED?style=flat-square&logo=docker)
![Kubernetes](https://img.shields.io/badge/Orchestration-Kubernetes-326CE5?style=flat-square&logo=kubernetes)
![AWS](https://img.shields.io/badge/Cloud-AWS%20EC2-FF9900?style=flat-square&logo=amazon-aws)
![Nginx](https://img.shields.io/badge/Server-Nginx-009639?style=flat-square&logo=nginx)

> A production-grade GitOps pipeline that automatically builds, pushes, and deploys a containerized Nginx web application to Kubernetes using Jenkins CI and ArgoCD CD — all running on AWS EC2.

---

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Live Demo](#-live-demo)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Repository Structure](#-repository-structure)
- [Prerequisites](#-prerequisites)
- [Setup Guide](#-setup-guide)
  - [Step 1 — AWS EC2 Setup](#step-1--aws-ec2-setup)
  - [Step 2 — Install Dependencies](#step-2--install-dependencies)
  - [Step 3 — Create kind Cluster](#step-3--create-kind-cluster)
  - [Step 4 — Install ArgoCD](#step-4--install-argocd)
  - [Step 5 — Install Jenkins](#step-5--install-jenkins)
  - [Step 6 — Configure Jenkins](#step-6--configure-jenkins)
  - [Step 7 — Deploy Application](#step-7--deploy-application)
  - [Step 8 — Configure GitHub Webhook](#step-8--configure-github-webhook)
- [CI/CD Pipeline](#-cicd-pipeline)
- [GitOps Flow](#-gitops-flow)
- [Kubernetes Manifests](#-kubernetes-manifests)
- [Update Application Version](#-update-application-version)
- [Access URLs](#-access-urls)
- [Troubleshooting](#-troubleshooting)
- [Key Learnings](#-key-learnings)

---

## 📌 Project Overview

This project implements a **complete GitOps workflow** for deploying a web application:

- **Application**: UN Enterprise — Quantitative Trading company website (single-file HTML/CSS/JS)
- **Containerized** with Docker using Nginx Alpine as the base image
- **Orchestrated** on Kubernetes (kind cluster) running on AWS EC2
- **CI pipeline** via Jenkins — builds image, pushes to Docker Hub, updates manifest
- **CD pipeline** via ArgoCD — watches GitHub repo and auto-deploys on every commit
- **GitOps principle**: Git is the single source of truth. No manual `kubectl apply` in production

### What Happens on Every `git push`

```
Developer pushes code
        ↓
GitHub Webhook triggers Jenkins
        ↓
Jenkins builds Docker image → pushes to Docker Hub
        ↓
Jenkins updates image tag in deployment.yaml → pushes to GitHub
        ↓
ArgoCD detects change in GitHub repo
        ↓
ArgoCD applies rolling update to Kubernetes cluster
        ↓
New version live at http://<EC2-IP>
```

---

## 🌐 Live Demo

| Service   | URL                              |
|-----------|----------------------------------|
| App       | `http://3.6.89.121`              |
| App (K8s) | `http://3.6.89.121:30007`        |
| ArgoCD UI | `https://3.6.89.121:31624`       |
| Jenkins   | `http://3.6.89.121:8080`         |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Developer                            │
│                     git push → main                         │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                      GitHub                                 │
│            ujwalnagrikar/GitOps-Project                     │
│   ┌─────────────────┐     ┌──────────────────────────────┐  │
│   │  app/           │     │  deployment.yaml             │  │
│   │  ├─ Dockerfile  │     │  service.yaml                │  │
│   │  ├─ index.html  │     │  argocd-app.yaml             │  │
│   │  └─ nginx.conf  │     │  Jenkinsfile                 │  │
│   └─────────────────┘     └──────────────────────────────┘  │
└──────┬────────────────────────────────────┬─────────────────┘
       │ Webhook                            │ Poll / Webhook
       ▼                                    ▼
┌─────────────────┐              ┌─────────────────────────┐
│    Jenkins      │              │        ArgoCD           │
│   (Port 8080)   │              │    (Port 31624)         │
│                 │              │                         │
│ 1. Checkout     │              │ 1. Detect YAML change   │
│ 2. Set tag      │              │ 2. Pull manifest        │
│ 3. Docker build │              │ 3. kubectl apply        │
│ 4. Docker push  │              │ 4. Rolling update       │
│ 5. Update YAML  │              │ 5. Self-heal            │
│ 6. git push     │              └────────────┬────────────┘
└────────┬────────┘                           │
         │                                    │
         ▼                                    ▼
┌────────────────┐              ┌─────────────────────────┐
│   Docker Hub   │              │   Kubernetes (kind)     │
│  ujwalnagrikar │              │   AWS EC2 Host          │
│  /pipeline-    │◄─────────────│                         │
│  monitor:v1    │  image pull  │  ┌───────────────────┐  │
└────────────────┘              │  │ pipeline-monitor  │  │
                                │  │ Deployment        │  │
                                │  │ replicas: 2       │  │
                                │  │ port: 80          │  │
                                │  └───────────────────┘  │
                                │  ┌───────────────────┐  │
                                │  │ NodePort Service  │  │
                                │  │ 80 → 30007        │  │
                                │  └───────────────────┘  │
                                └─────────────────────────┘
```

### Infrastructure Layers

```
AWS EC2 (Ubuntu 24.04)
│
├── Docker Engine
│   └── kind Control Plane Container
│       └── Kubernetes Cluster (argocd-cluster)
│           ├── namespace: default
│           │   ├── Deployment: pipeline-monitor (2 replicas)
│           │   └── Service: pipeline-monitor-service (NodePort 30007)
│           └── namespace: argocd
│               └── ArgoCD (NodePort 31624)
│
├── Jenkins (systemd service, port 8080)
└── Nginx (systemd service, port 80) ← direct fallback
```

---

## 🛠️ Tech Stack

| Tool             | Version  | Role                                              |
|------------------|----------|---------------------------------------------------|
| **Jenkins**      | LTS      | CI — build image, push to Hub, update manifest   |
| **Docker**       | Latest   | Containerize Nginx + HTML app                     |
| **Kubernetes**   | 1.32     | Orchestrate and manage application pods           |
| **kind**         | 0.27+    | Run K8s cluster inside Docker on EC2              |
| **ArgoCD**       | v3.3.3   | GitOps CD — auto-sync from GitHub to K8s          |
| **Nginx**        | Alpine   | Serve the web application                         |
| **AWS EC2**      | t2.medium| Cloud host — Ubuntu 24.04, 20GB EBS              |
| **GitHub**       | —        | Source code + K8s manifests (source of truth)    |
| **Docker Hub**   | —        | Container image registry                          |

---

## 📁 Repository Structure

```
GitOps-Project/
│
├── app/
│   ├── Dockerfile          # Nginx Alpine container — EXPOSE 80
│   ├── index.html          # UN Enterprise website (single HTML file)
│   └── nginx.conf          # Nginx config — listen 80, gzip, security headers
│
├── deployment.yaml         # K8s Deployment — 2 replicas, probes, resource limits
├── service.yaml            # K8s NodePort Service — port 80 → nodePort 30007
├── argocd-app.yaml         # ArgoCD Application CRD — auto-sync from GitHub
├── Jenkinsfile             # Jenkins declarative pipeline — 6 stages
├── kind-config.yaml        # kind cluster — extraPortMappings for NodePort access
├── deploy.sh               # One-click full environment setup script
└── README.md
```

---

## ✅ Prerequisites

### Local Machine (Windows)
- Git installed
- Docker Desktop (optional — for local testing)
- PowerShell

### AWS EC2 Instance
- **OS**: Ubuntu 24.04 LTS
- **Instance Type**: t2.medium (2 vCPU, 4GB RAM minimum)
- **Storage**: 20GB EBS
- **Security Group**: Open ports below

### AWS Security Group — Required Inbound Rules

| Port  | Protocol | Source    | Service               |
|-------|----------|-----------|-----------------------|
| 22    | TCP      | Your IP   | SSH                   |
| 80    | TCP      | 0.0.0.0/0 | Nginx (direct)        |
| 8080  | TCP      | 0.0.0.0/0 | Jenkins               |
| 30007 | TCP      | 0.0.0.0/0 | App via NodePort      |
| 31624 | TCP      | 0.0.0.0/0 | ArgoCD HTTPS          |
| 31774 | TCP      | 0.0.0.0/0 | ArgoCD HTTP           |

---

## 🚀 Setup Guide

### Step 1 — AWS EC2 Setup

Launch EC2 instance with Ubuntu 24.04, then SSH in:

```bash
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>
```

Update system:

```bash
sudo apt update && sudo apt upgrade -y
```

---

### Step 2 — Install Dependencies

```bash
# Install Docker
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x kind && sudo mv kind /usr/local/bin/kind

# Install Git
sudo apt install -y git

# Verify installations
docker --version && kubectl version --client && kind version
```

---

### Step 3 — Create kind Cluster

> ⚠️ **Critical**: Create the config file BEFORE creating the cluster. The `extraPortMappings` are required for NodePort access from outside EC2.

```bash
# Create cluster config
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: argocd-cluster
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30007
    hostPort: 30007
    protocol: TCP
  - containerPort: 31774
    hostPort: 31774
    protocol: TCP
  - containerPort: 31624
    hostPort: 31624
    protocol: TCP
EOF

# Create the cluster
kind create cluster --config kind-config.yaml

# Verify
kubectl get nodes
# NAME                          STATUS   ROLES
# argocd-cluster-control-plane  Ready    control-plane
```

---

### Step 4 — Install ArgoCD

```bash
# Create namespace and install
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=300s

# Expose via NodePort
kubectl patch svc argocd-server -n argocd \
  -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":31774,"name":"http"},{"port":443,"nodePort":31624,"name":"https"}]}}'

# Get admin password
kubectl get secret argocd-initial-admin-secret \
  -n argocd -o jsonpath="{.data.password}" | base64 -d && echo

# Access ArgoCD UI
# https://<EC2-PUBLIC-IP>:31624
# Username: admin
# Password: (from command above)
```

---

### Step 5 — Install Jenkins

```bash
# Install Java (required)
sudo apt install -y openjdk-17-jdk

# Add Jenkins repo
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
  sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update && sudo apt install -y jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Add jenkins to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Copy kubeconfig for Jenkins
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp /root/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Access Jenkins
# http://<EC2-PUBLIC-IP>:8080
```

---

### Step 6 — Configure Jenkins

#### Install Required Plugins

Go to `Manage Jenkins → Plugins → Available`:

| Plugin                    | Purpose                       |
|---------------------------|-------------------------------|
| Git                       | Clone GitHub repositories     |
| GitHub Integration        | Webhook trigger               |
| Docker Pipeline           | Build and push Docker images  |
| Pipeline                  | Jenkinsfile support           |
| Credentials Binding       | Use secrets in pipeline       |

#### Add Credentials

Go to `Manage Jenkins → Credentials → System → Global → Add Credentials`:

**Docker Hub:**
```
Kind     : Username with password
Username : ujwalnagrikar
Password : <dockerhub-password>
ID       : dockerhub-credentials
```

**GitHub:**
```
Kind     : Username with password
Username : ujwalnagrikar
Password : <github-personal-access-token>
ID       : github-credentials
```

> **Create GitHub Token**: GitHub → Settings → Developer Settings → Personal Access Tokens → Generate → select `repo` scope

#### Create Pipeline Job

```
Jenkins → New Item → gitops-pipeline → Pipeline → OK

Pipeline section:
  Definition  : Pipeline script from SCM
  SCM         : Git
  Repo URL    : https://github.com/ujwalnagrikar/GitOps-Project.git
  Credentials : github-credentials
  Branch      : */main
  Script Path : Jenkinsfile

Build Triggers:
  ✓ GitHub hook trigger for GITScm polling

→ Save
```

---

### Step 7 — Deploy Application

```bash
cd /home/ubuntu

# Clone your repo
git clone https://github.com/ujwalnagrikar/GitOps-Project.git
cd GitOps-Project

# Apply manifests
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f argocd-app.yaml

# Verify pods
kubectl get pods
# NAME                                READY   STATUS    RESTARTS   AGE
# pipeline-monitor-xxx-xxx   1/1     Running   0          30s

# Setup Nginx on EC2 for direct access
sudo apt install -y nginx
sudo cp app/index.html /var/www/html/index.html
sudo systemctl restart nginx
```

---

### Step 8 — Configure GitHub Webhook

```
GitHub → GitOps-Project → Settings → Webhooks → Add Webhook

Payload URL  : http://<EC2-PUBLIC-IP>:8080/github-webhook/
Content type : application/json
Events       : Just the push event
Active       : ✓

→ Add Webhook
```

---

## 🔄 CI/CD Pipeline

The Jenkins pipeline is defined in `Jenkinsfile` with 6 stages:

```
┌──────────┐   ┌──────────────┐   ┌──────────────┐
│ Checkout │──▶│ Set Image Tag│──▶│ Build Image  │
└──────────┘   └──────────────┘   └──────────────┘
                                         │
                                         ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│   Verify     │◀──│Update Manifest│◀──│Push to Hub   │
└──────────────┘   └──────────────┘   └──────────────┘
```

| Stage            | Description                                               |
|------------------|-----------------------------------------------------------|
| **Checkout**     | Clone repo from GitHub using credentials                  |
| **Set Image Tag**| Get short Git commit SHA (e.g. `a3f9c1b`) as version tag  |
| **Build Image**  | `docker build -t ujwalnagrikar/pipeline-monitor:SHA ./app`|
| **Push to Hub**  | Push `:SHA` and `:latest` tags to Docker Hub             |
| **Update Manifest**| `sed` update image tag in `deployment.yaml`, `git push` |
| **Verify**       | Wait 20s for ArgoCD sync, then `kubectl get pods`         |

---

## 🔁 GitOps Flow

```
                    ┌─────────────┐
                    │  Developer  │
                    └──────┬──────┘
                           │ git push
                           ▼
                    ┌─────────────┐
                    │   GitHub    │◄──── Jenkins pushes
                    │  (main)     │      updated YAML
                    └──────┬──────┘
                           │ Webhook
          ┌────────────────┤
          │                │ Poll (3 min)
          ▼                ▼
   ┌─────────────┐  ┌─────────────┐
   │   Jenkins   │  │   ArgoCD    │
   │   (CI)      │  │   (CD)      │
   └──────┬──────┘  └──────┬──────┘
          │                │
          │ push image     │ kubectl apply
          ▼                ▼
   ┌─────────────┐  ┌─────────────┐
   │ Docker Hub  │  │ Kubernetes  │
   └─────────────┘  └─────────────┘
```

---

## 📄 Kubernetes Manifests

### deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pipeline-monitor
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pipeline-monitor
  template:
    spec:
      containers:
      - name: pipeline-monitor
        image: ujwalnagrikar/pipeline-monitor:v1
        ports:
        - containerPort: 80        # must match nginx listen port
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        readinessProbe:
          httpGet: { path: /, port: 80 }
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet: { path: /, port: 80 }
          initialDelaySeconds: 10
          periodSeconds: 15
```

### service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: pipeline-monitor-service
spec:
  type: NodePort
  selector:
    app: pipeline-monitor
  ports:
    - port: 80
      targetPort: 80    # must match containerPort
      nodePort: 30007
```

> ⚠️ **Critical Port Alignment**: `nginx.conf listen` = `Dockerfile EXPOSE` = `containerPort` = `targetPort` = **80**

---

## 🔄 Update Application Version

### On Linux (EC2)

```bash
# Update image tag
sed -i 's|image: ujwalnagrikar/pipeline-monitor:.*|image: ujwalnagrikar/pipeline-monitor:v2|' deployment.yaml

# Push to GitHub — ArgoCD will auto-sync
git add deployment.yaml
git commit -m "deploy: update image to v2"
git push origin main
```

### On Windows (PowerShell)

```powershell
# Update image tag
(Get-Content deployment.yaml) -replace 'image: ujwalnagrikar/pipeline-monitor:.*', `
  'image: ujwalnagrikar/pipeline-monitor:v2' | Set-Content deployment.yaml

# Push to GitHub
git add deployment.yaml ; git commit -m "deploy: update image to v2" ; git push origin main
```

### Build and Push New Image

```bash
docker build -t ujwalnagrikar/pipeline-monitor:v2 \
             -t ujwalnagrikar/pipeline-monitor:latest ./app
docker push ujwalnagrikar/pipeline-monitor:v2
docker push ujwalnagrikar/pipeline-monitor:latest
```

---

## 🌐 Access URLs

| Service       | URL                             | Credentials               |
|---------------|---------------------------------|---------------------------|
| App (Nginx)   | `http://3.6.89.121`             | —                         |
| App (NodePort)| `http://3.6.89.121:30007`       | —                         |
| ArgoCD        | `https://3.6.89.121:31624`      | admin / (from secret)     |
| Jenkins       | `http://3.6.89.121:8080`        | admin / (set on setup)    |

```bash
# Get ArgoCD password
kubectl get secret argocd-initial-admin-secret \
  -n argocd -o jsonpath="{.data.password}" | base64 -d && echo
```

---

## 🔧 Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Connection refused on port 30007 | kind cluster missing `extraPortMappings` | Recreate cluster with `kind-config.yaml` |
| `Forwarding → 8080` instead of `→ 80` | `service.yaml targetPort: 8080` | Fix to `targetPort: 80`, delete and reapply service |
| Port 8080 already in use | Jenkins occupies 8080 | Use port 7000 for `kubectl port-forward` |
| Old version showing in browser | Browser cache | Hard refresh `Ctrl+Shift+R` |
| App not accessible from browser | Security Group missing rule | Add inbound rule for the port |
| ArgoCD shows OutOfSync | Manifest changed outside ArgoCD | `argocd app sync my-git-ops-project --force` |
| Pods in CrashLoopBackOff | Image pull error or wrong port | `kubectl logs <pod>` and `kubectl describe pod <pod>` |
| `sed` not updating image tag | Inline YAML comments in deployment.yaml | Remove all inline comments from YAML files |
| Jenkins can't run kubectl | Missing kubeconfig | `sudo cp ~/.kube/config /var/lib/jenkins/.kube/config` |

---

## 💡 Key Learnings

### Critical Gotchas

1. **kind + NodePort** — kind clusters do not expose NodePorts to the EC2 host by default. `extraPortMappings` in `kind-config.yaml` is **mandatory** — create the config file BEFORE the cluster
2. **Port alignment** — Every layer must agree on port 80: `nginx.conf` → `Dockerfile` → `containerPort` → `targetPort`. Any mismatch causes silent connection refused
3. **Jenkins on 8080** — Never use port 8080 for `kubectl port-forward` on the same machine as Jenkins
4. **No inline YAML comments** — Comments after values (`containerPort: 80 # comment`) break `sed` replacement on Linux
5. **Security Group first** — Always check AWS Security Group before debugging Kubernetes. It's the most common cause of external inaccessibility

### GitOps Best Practices

- **Git = source of truth** — Never run `kubectl apply` manually in production
- **Immutable image tags** — Use Git commit SHA, never overwrite `:latest` in production
- **selfHeal: true** — ArgoCD reverts any manual cluster changes automatically
- **Readiness probes** — Prevent traffic routing to unhealthy pods during rolling updates
- **Declarative everything** — Cluster config, app config, and pipeline all in Git

---

## 📊 Quick Reference Commands

```bash
# ── Pods & Services ──────────────────────────────────────
kubectl get pods                                     # list pods
kubectl get pods -o wide                             # with node info
kubectl get svc                                      # list services
kubectl describe pods -l app=pipeline-monitor        # pod details
kubectl logs <pod-name>                              # pod logs
kubectl rollout restart deployment pipeline-monitor  # restart pods
kubectl rollout status deployment pipeline-monitor   # rollout status

# ── ArgoCD ───────────────────────────────────────────────
kubectl get application -n argocd                    # app status
argocd app sync my-git-ops-project                   # force sync
argocd app get my-git-ops-project                    # app details
argocd app list                                      # all apps

# ── kind Cluster ─────────────────────────────────────────
kind get clusters                                    # list clusters
kind create cluster --config kind-config.yaml        # create
kind delete cluster --name argocd-cluster            # delete

# ── Docker ───────────────────────────────────────────────
docker build -t ujwalnagrikar/pipeline-monitor:v1 ./app
docker push ujwalnagrikar/pipeline-monitor:v1
docker images | grep pipeline-monitor
docker ps                                            # running containers

# ── Nginx on EC2 ─────────────────────────────────────────
sudo cp app/index.html /var/www/html/index.html
sudo systemctl restart nginx
sudo systemctl status nginx
```

---

## 📜 License

This project is open source and available under the [MIT License](LICENSE).

---

## 👤 Author

**Ujwal Nagrikar**
DevOps & Cloud Engineer | Nagpur, India

[![GitHub](https://img.shields.io/badge/GitHub-ujwalnagrikar-black?style=flat-square&logo=github)](https://github.com/ujwalnagrikar)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?style=flat-square&logo=linkedin)](https://linkedin.com/in/ujwalnagrikar)
[![Docker Hub](https://img.shields.io/badge/DockerHub-ujwalnagrikar-2496ED?style=flat-square&logo=docker)](https://hub.docker.com/u/ujwalnagrikar)

---

<div align="center">
  <sub>Built with Jenkins · ArgoCD · Kubernetes · Docker · AWS</sub>
</div>
