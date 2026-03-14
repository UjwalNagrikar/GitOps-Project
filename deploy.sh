#!/bin/bash
# ============================================================
#  UN Enterprise — GitOps Full Deploy Script
#  Run this on your EC2 instance
# ============================================================
set -e

DOCKER_USERNAME="ujwalnagrikar"
IMAGE_NAME="pipeline-monitor"
TAG=${1:-v1}

echo ""
echo "======================================================"
echo "  UN Enterprise GitOps Deploy — Tag: $TAG"
echo "======================================================"
echo ""

# ─────────────────────────────────────
# STEP 1 — Create kind cluster
# ─────────────────────────────────────
echo "🔧 STEP 1 — Creating kind cluster with port mappings..."

if kind get clusters | grep -q "argocd-cluster"; then
    echo "⚠️  Cluster already exists — skipping creation"
else
    kind create cluster --config kind-config.yaml
    echo "✅ Cluster created"
fi

# ─────────────────────────────────────
# STEP 2 — Install ArgoCD
# ─────────────────────────────────────
echo ""
echo "🔧 STEP 2 — Installing ArgoCD..."

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=argocd-server \
    -n argocd --timeout=300s

echo "✅ ArgoCD ready"

# ─────────────────────────────────────
# STEP 3 — Patch ArgoCD to NodePort
# ─────────────────────────────────────
echo ""
echo "🔧 STEP 3 — Exposing ArgoCD via NodePort..."

kubectl patch svc argocd-server -n argocd \
    -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":31774,"name":"http"},{"port":443,"nodePort":31624,"name":"https"}]}}'

echo "✅ ArgoCD exposed on ports 31774 (HTTP) and 31624 (HTTPS)"

# ─────────────────────────────────────
# STEP 4 — Build & Push Docker Image
# ─────────────────────────────────────
echo ""
echo "🔧 STEP 4 — Building Docker image: $TAG..."

docker build -t $DOCKER_USERNAME/$IMAGE_NAME:$TAG \
             -t $DOCKER_USERNAME/$IMAGE_NAME:latest \
             ./app

echo "🚀 Pushing to Docker Hub..."
docker push $DOCKER_USERNAME/$IMAGE_NAME:$TAG
docker push $DOCKER_USERNAME/$IMAGE_NAME:latest
echo "✅ Image pushed: $DOCKER_USERNAME/$IMAGE_NAME:$TAG"

# ─────────────────────────────────────
# STEP 5 — Update deployment.yaml tag
# ─────────────────────────────────────
echo ""
echo "🔧 STEP 5 — Updating deployment.yaml to tag: $TAG..."

sed -i "s|image: $DOCKER_USERNAME/$IMAGE_NAME:.*|image: $DOCKER_USERNAME/$IMAGE_NAME:$TAG|g" deployment.yaml
grep 'image:' deployment.yaml
echo "✅ deployment.yaml updated"

# ─────────────────────────────────────
# STEP 6 — Apply K8s Manifests
# ─────────────────────────────────────
echo ""
echo "🔧 STEP 6 — Applying Kubernetes manifests..."

kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
echo "✅ Manifests applied"

# ─────────────────────────────────────
# STEP 7 — Apply ArgoCD App
# ─────────────────────────────────────
echo ""
echo "🔧 STEP 7 — Creating ArgoCD Application..."

kubectl apply -f argocd-app.yaml
echo "✅ ArgoCD app created"

# ─────────────────────────────────────
# STEP 8 — Wait for Pods
# ─────────────────────────────────────
echo ""
echo "🔧 STEP 8 — Waiting for pods to be ready..."

kubectl wait --for=condition=ready pod \
    -l app=pipeline-monitor --timeout=120s

echo "✅ Pods ready"

# ─────────────────────────────────────
# STEP 9 — Get ArgoCD Password
# ─────────────────────────────────────
echo ""
echo "🔧 STEP 9 — Fetching ArgoCD credentials..."

ARGOCD_PASS=$(kubectl get secret argocd-initial-admin-secret \
    -n argocd \
    -o jsonpath="{.data.password}" | base64 -d)

# ─────────────────────────────────────
# STEP 10 — Setup Nginx on EC2
# ─────────────────────────────────────
echo ""
echo "🔧 STEP 10 — Setting up Nginx on EC2..."

sudo apt install -y nginx -q
sudo cp app/index.html /var/www/html/index.html
sudo systemctl restart nginx
echo "✅ Nginx serving app on port 80"

# ─────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo ""
echo "======================================================"
echo "  ✅ DEPLOYMENT COMPLETE"
echo "======================================================"
echo ""
echo "  🌐 App URL      : http://$PUBLIC_IP"
echo "  🌐 App NodePort : http://$PUBLIC_IP:30007"
echo "  🔐 ArgoCD UI    : https://$PUBLIC_IP:31624"
echo "  👤 ArgoCD User  : admin"
echo "  🔑 ArgoCD Pass  : $ARGOCD_PASS"
echo "  🐳 Docker Image : $DOCKER_USERNAME/$IMAGE_NAME:$TAG"
echo ""
echo "  Open ports in AWS Security Group:"
echo "    80    → App (Nginx)"
echo "    30007 → App (NodePort)"
echo "    31624 → ArgoCD HTTPS"
echo "    8080  → Jenkins"
echo "======================================================"
