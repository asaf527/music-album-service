#!/bin/bash

set -e  # Exit on error

# Function to check if a command is installed
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Docker is installed, install it if not
if ! check_command docker; then
    echo "🐳 Docker not found. Installing Docker... ⬇️"
    sudo apt update -y
    sudo apt install -y docker.io
else
    echo "✅ Docker is already installed."
fi

# Check if Minikube is installed, install it if not
if ! check_command minikube; then
    echo "🚀 Minikube not found. Installing Minikube... ⬇️"
    sudo apt update -y
    sudo apt install -y curl
    curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube /usr/local/bin/
else
    echo "✅ Minikube is already installed."
fi

# Check if kubectl is installed, install it if not
if ! check_command kubectl; then
    echo "☸️ kubectl not found. Installing kubectl... ⬇️"
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubectl
    echo "✅ kubectl has been installed successfully."
else
    echo "✅ kubectl is already installed."
fi

# Function to check if a variable is empty or unset
check_empty() {
    local var_name="$1"
    local var_value="$2"
    if [[ -z "$var_value" ]]; then
        return 0  # Empty
    else
        return 1  # Not empty
    fi
}

# Function to securely read password
read_password() {
    local prompt="$1"
    local password=""
    
    # Use read -sp for secure password input (no echo)
    read -sp "$prompt" password
    echo  # Add a newline after password input
    echo "$password"
}

# Ensure the current user is part of the Docker group
echo "🛠️ Adding $USER to the Docker group..."
sudo chmod 666 /var/run/docker.sock
sudo usermod -aG docker $USER

# Prompt to log out and log back in to apply group changes
echo "🔑 Please log out and log back in for the Docker group changes to take effect."
echo "🔄 After logging back in, run the script again without 'sudo'."

# Minikube setup without root privileges
# This section will now run as the current user, not root
echo "🚀 Starting Minikube with Docker driver..."
minikube start --driver=docker || (minikube delete && minikube start --driver=docker)

# Enable ingress
echo "🔌 Enabling ingress..."
minikube addons enable ingress

# Check and handle DOCKER_USERNAME
if check_empty "DOCKER_USERNAME" "$DOCKER_USERNAME"; then
    echo "Docker Hub username not set"
    read -p "Enter Docker Hub username: " username
    export DOCKER_USERNAME="$username"
else
    echo "Docker Hub username is already set"
fi

# Check and handle DOCKER_PASSWORD
if check_empty "DOCKER_PASSWORD" "$DOCKER_PASSWORD"; then
    echo "Docker Hub password not set"
    DOCKER_PASSWORD=$(read_password "Enter Docker Hub password: ")
    export DOCKER_PASSWORD="$DOCKER_PASSWORD"
else
    echo "Docker Hub password is already set"
fi

# Perform Docker login interactively (recommended)
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

# Build and push Docker image
echo "🔨 Building Docker image..."
docker build -t "$DOCKER_USERNAME/music-server:latest" .
docker push "$DOCKER_USERNAME/music-server:latest"

# Deploy Redis components
echo "🐍 Deploying Redis components in 'music-app' namespace..."
kubectl apply -f namespace.yaml
kubectl apply -f redis-secret.yaml
kubectl apply -f redis-config.yaml
kubectl apply -f redis-deployment.yaml

# Wait for Redis pod to be in Running state
echo "⏳ Waiting for Redis pod to be ready in 'music-app' namespace..."
kubectl wait --for=condition=ready pod -l app=redis -n music-app --timeout=60s

# Deploy Web Server
echo "🌐 Deploying Web Server in 'music-app' namespace..."
kubectl apply -f webserver-deployment.yaml -n music-app
kubectl apply -f network-policy.yaml -n music-app

# Generate TLS Certificate
echo "🔒 Generating TLS certificate..."
cd certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=music.local"
kubectl create secret tls music-tls --cert=tls.crt --key=tls.key -n music-app
cd ..

# Deploy Ingress
echo "🔀 Deploying Ingress in 'music-app' namespace..."
kubectl apply -f ingress.yaml -n music-app


# Copy Redis dump file
# Copy Redis dump file using dynamic pod selection
echo "📦 Copying Redis dump file to pod in 'music-app' namespace..."

# Get the Redis pod dynamically
redis_pod=$(kubectl get pods -n music-app -l app=redis -o jsonpath="{.items[0].metadata.name}")

# If the pod is found, copy the dump file
if [[ -n "$redis_pod" ]]; then
    kubectl cp data/dump.rdb "$redis_pod:/data/dump.rdb" -n music-app
else
    echo "❌ Redis pod not found!"
fi

# Restart Redis deployment
echo "🔄 Restarting Redis deployment in 'music-app' namespace..."
kubectl rollout restart deployment redis -n music-app

echo "✅ Setup complete in 'music-app' namespace. Access the service via HTTPS. 🌐"

# Show service details
kubectl get svc,ingress,pods -n music-app

echo "192.168.49.2 music.local" | sudo tee -a /etc/hosts

