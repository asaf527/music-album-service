# Music Albums Service - Kubernetes Deployment

This repository contains the Kubernetes deployment configuration for the Music Albums service, a web API that serves album information from a Redis backend.

## Architecture Overview

The application consists of:
- Web API service (Go-based) with multiple replicas
- Redis database for data storage
- Ingress controller for TLS termination
- Network policies for service isolation

## Prerequisites

- Ubuntu 22.04.3 LTS
- Minimum system requirements:
  - 4GB RAM
  - 2 CPU cores
  - 20GB free disk space

## Quick Start

1. Clone this repository:
```bash
git clone <repository-url>
cd music-albums-service
```

2. Run the setup script:
```bash
./setup.sh
```

The script will:
- Install required dependencies (Docker, Minikube, kubectl)
- Set up a Minikube cluster
- Build and deploy the application
- Configure TLS and ingress

## Manual Setup

If you prefer to deploy manually or understand the deployment process:

1. Install dependencies:
```bash
# Install Docker
sudo apt update && sudo apt install -y docker.io

# Install Minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube /usr/local/bin/

# Install kubectl
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update && sudo apt-get install -y kubectl
```

2. Start Minikube:
```bash
minikube start --driver=docker
minikube addons enable ingress
```

3. Deploy components:
```bash
# Create namespace and deploy Redis
kubectl apply -f namespace.yaml
kubectl apply -f redis-secret.yaml
kubectl apply -f redis-config.yaml
kubectl apply -f redis-deployment.yaml

# Deploy web service
kubectl apply -f webserver-deployment.yaml
kubectl apply -f network-policy.yaml

# Configure TLS and ingress
kubectl apply -f ingress.yaml
```

## Configuration

### Redis Configuration
- Password is stored in `redis-secret.yaml`
- Data persistence configured via PVC
- Network access restricted to web service pods

### Web Service Configuration
- Replicas: 3 (configurable in `webserver-deployment.yaml`)
- Resource limits: 200m CPU, 256Mi memory per replica
- Health checks: TCP probe on port 9090
- TLS termination at ingress

## Accessing the Service

1. Add DNS entry to /etc/hosts:
```bash
echo "192.168.49.2 music.local" | sudo tee -a /etc/hosts
```

2. Access the service:
```bash
curl -k https://music.local/api/v1/music-albums?key=1
```

## Monitoring and Maintenance

Check service status:
```bash
kubectl get svc,ingress,pods -n music-app
```

View logs:
```bash
# Web service logs
kubectl logs -f -l app=music-app -n music-app

# Redis logs
kubectl logs -f -l app=redis -n music-app
```

## Troubleshooting

Common issues and solutions:

1. Pods not starting:
```bash
kubectl describe pod <pod-name> -n music-app
```

2. Redis connection issues:
```bash
# Verify Redis is running
kubectl exec -it $(kubectl get pod -l app=redis -n music-app -o jsonpath='{.items[0].metadata.name}') -n music-app -- redis-cli ping
```

3. TLS certificate issues:
```bash
# Recreate TLS certificate
cd certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=music.local"
kubectl create secret tls music-tls --cert=tls.crt --key=tls.key -n music-app --dry-run=client -o yaml | kubectl apply -f -
```

## Security Considerations

- Redis password protection enabled
- Network policies restrict pod communication
- TLS encryption for external access
- Non-root container execution
- Resource limits enforced

## Contributing

1. Fork the repository
2. Create your feature branch
3. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.