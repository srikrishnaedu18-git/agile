# 🚀 Java CI/CD Pipeline — Jenkins + Docker + Kubernetes

A complete end-to-end CI/CD pipeline that automatically builds a Java application, containerizes it with Docker, pushes it to DockerHub, and deploys it to a Kubernetes cluster using Minikube — all orchestrated by Jenkins.

---

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Setup Guide](#-setup-guide)
  - [Step 1 — Install Minikube](#step-1--install-minikube)
  - [Step 2 — Build Custom Jenkins Image](#step-2--build-custom-jenkins-image)
  - [Step 3 — Run Jenkins Container](#step-3--run-jenkins-container)
  - [Step 4 — Fix Docker Socket Permissions](#step-4--fix-docker-socket-permissions)
  - [Step 5 — Fix kubeconfig Paths](#step-5--fix-kubeconfig-paths)
  - [Step 6 — Configure Jenkins](#step-6--configure-jenkins)
  - [Step 7 — Create Jenkins Pipeline](#step-7--create-jenkins-pipeline)
- [Source Code](#-source-code)
- [Pipeline Stages](#-pipeline-stages)
- [Running the Pipeline](#-running-the-pipeline)
- [Verify Deployment](#-verify-deployment)
- [Errors & Fixes](#-errors--fixes)
- [Useful Commands](#-useful-commands)

---

## 📌 Project Overview

This project implements a **production-style DevOps pipeline** using open-source tools. A simple Java application is automatically built, containerized, and deployed to Kubernetes every time code is pushed to GitHub.

```
GitHub Push → Jenkins → Maven Build → Docker Image → DockerHub → Kubernetes (Minikube)
```

---

## 🏗 Architecture

```
┌─────────────┐     push      ┌─────────────┐
│   Developer  │ ────────────▶ │   GitHub    │
└─────────────┘               └──────┬──────┘
                                      │ trigger
                               ┌──────▼──────┐
                               │   Jenkins   │
                               │  (Docker)   │
                               └──────┬──────┘
                        ┌─────────────┼─────────────┐
                        ▼             ▼              ▼
                   mvn build     docker build    kubectl apply
                        │             │              │
                   JAR file     DockerHub       Minikube
                                  Image          Cluster
```

---

## 🛠 Tech Stack

| Tool | Version | Purpose |
|------|---------|---------|
| Jenkins | LTS | CI/CD automation |
| Maven | 3.x | Java build tool |
| Docker | 26.1.5 | Containerization |
| Kubernetes | Minikube | Local K8s cluster |
| kubectl | v1.35.3 | K8s CLI |
| Java | 17 (Eclipse Temurin) | App runtime |
| GitHub | - | Source code repository |
| DockerHub | - | Container image registry |

---

## 📁 Project Structure

```
simple-java-app/
├── Dockerfile              # Java app container image
├── Jenkinsfile             # CI/CD pipeline definition
├── deployment.yaml         # Kubernetes Deployment
├── service.yaml            # Kubernetes NodePort Service
├── pom.xml                 # Maven build config
└── src/
    └── main/
        └── java/
            └── App.java    # Main Java application
```

> **Note:** `Dockerfile.jenkins` lives on your **host machine only** — it is not part of the repo.

---

## ✅ Prerequisites

Make sure these are installed on your host machine before starting:

- [Docker](https://docs.docker.com/get-docker/)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- A [DockerHub](https://hub.docker.com/) account
- A [GitHub](https://github.com/) account

---

## 🔧 Setup Guide

### Step 1 — Install Minikube

```bash
# Install Minikube (Linux)
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start Minikube
minikube start

# Verify it's running
minikube status
```

Expected output:
```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

---

### Step 2 — Build Custom Jenkins Image

Create `Dockerfile.jenkins` on your **host machine** (not in the repo):

```dockerfile
FROM jenkins/jenkins:lts

USER root

# Install tools
RUN apt-get update && apt-get install -y \
    maven \
    docker.io \
    curl \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Add jenkins user to docker group
RUN usermod -aG docker jenkins

USER jenkins
```

Build the image:

```bash
docker build -t my-jenkins-full -f Dockerfile.jenkins .
```

---

### Step 3 — Run Jenkins Container

```bash
docker run -d \
  --name jenkins \
  --network host \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/krishna/.kube:/home/jenkins/.kube \
  -v /home/krishna/.minikube:/home/jenkins/.minikube \
  my-jenkins-full
```

> Replace `/home/krishna` with your actual home directory path.

Access Jenkins at: **http://localhost:8080**

Get the initial admin password:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Complete the Jenkins setup wizard and install the **suggested plugins**.

---

### Step 4 — Fix Docker Socket Permissions

Run this **from your host machine** (not inside the container):

```bash
docker exec -u root jenkins bash -c "
  DOCKER_GID=\$(stat -c '%g' /var/run/docker.sock) && \
  groupadd -g \$DOCKER_GID docker_host 2>/dev/null || true && \
  usermod -aG docker_host jenkins
"

# Restart Jenkins to apply group changes
docker restart jenkins

# Verify Docker works inside the container
docker exec -it jenkins bash -c "docker ps"
```

---

### Step 5 — Fix kubeconfig Paths

The kubeconfig mounted from the host uses `/home/krishna` paths. Jenkins needs `/home/jenkins` paths:

```bash
# Enter the Jenkins container
docker exec -it jenkins bash

# Fix the paths inside the container
sed -i 's#/home/krishna#/home/jenkins#g' /home/jenkins/.kube/config

# Verify kubectl works
kubectl get nodes

# Exit the container
exit
```

> ⚠️ **Important:** If you ever need to use kubectl on the **host machine** after this, run:
> ```bash
> sed -i 's#/home/jenkins#/home/krishna#g' ~/.kube/config
> ```

---

### Step 6 — Configure Jenkins

#### Add GitHub Credentials

1. Go to **Jenkins → Manage Jenkins → Credentials → Global → Add Credentials**
2. Kind: **Username with password**
3. Username: your GitHub username
4. Password: your GitHub personal access token
5. ID: `github_cred`

#### Add DockerHub Credentials

1. Go to **Jenkins → Manage Jenkins → Credentials → Global → Add Credentials**
2. Kind: **Username with password**
3. Username: your DockerHub username
4. Password: your DockerHub password
5. ID: `dockerhub-creds`

---

### Step 7 — Create Jenkins Pipeline

1. Go to **Jenkins → New Item**
2. Name: `java-cicd-pipeline`
3. Type: **Pipeline**
4. Under **Pipeline** section:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://github.com/your-username/your-repo.git`
   - Credentials: `github_cred`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
5. Click **Save**

---

## 💻 Source Code

### `App.java`

```java
public class App {
    public static void main(String[] args) {
        System.out.println("Hello from Jenkins CI/CD 🚀");
    }
}
```

---

### `pom.xml`

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">

    <modelVersion>4.0.0</modelVersion>
    <groupId>com.example</groupId>
    <artifactId>simple-java-app</artifactId>
    <version>1.0</version>

    <build>
        <plugins>
            <plugin>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.8.1</version>
                <configuration>
                    <source>17</source>
                    <target>17</target>
                </configuration>
            </plugin>
            <plugin>
                <artifactId>maven-jar-plugin</artifactId>
                <version>3.2.0</version>
                <configuration>
                    <archive>
                        <manifest>
                            <mainClass>App</mainClass>
                        </manifest>
                    </archive>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

---

### `Dockerfile`

> This is the **Java app** Dockerfile — goes inside the repo.

```dockerfile
FROM eclipse-temurin:17-jre
COPY target/simple-java-app-1.0.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

---

### `Jenkinsfile`

```groovy
pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "srikrishnaedu18docker/java-app"
        KUBECONFIG = "/home/jenkins/.kube/config"
    }

    stages {

        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Docker Build') {
            steps {
                sh 'docker build -t $DOCKER_IMAGE .'
            }
        }

        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push $DOCKER_IMAGE
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                kubectl apply -f deployment.yaml
                kubectl apply -f service.yaml
                '''
            }
        }

        stage('Verify') {
            steps {
                sh 'kubectl get pods'
            }
        }
    }
}
```

---

### `deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: java-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: java-app
  template:
    metadata:
      labels:
        app: java-app
    spec:
      containers:
      - name: java-app
        image: srikrishnaedu18docker/java-app:latest
        ports:
        - containerPort: 8080
```

---

### `service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: java-app-service
spec:
  type: NodePort
  selector:
    app: java-app
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
      nodePort: 30007
```

---

## 🔄 Pipeline Stages

| Stage | What It Does |
|-------|-------------|
| **Build** | Runs `mvn clean package` to compile and produce a JAR file |
| **Docker Build** | Runs `docker build` using the repo's Dockerfile to create the app image |
| **Docker Push** | Logs into DockerHub and pushes the image |
| **Deploy to Kubernetes** | Applies `deployment.yaml` and `service.yaml` to the Minikube cluster |
| **Verify** | Runs `kubectl get pods` to confirm the pod was created |

---

## ▶️ Running the Pipeline

1. Make sure Minikube is running:
   ```bash
   minikube start
   ```

2. Make sure Jenkins is running:
   ```bash
   docker start jenkins
   ```

3. Go to **Jenkins → java-cicd-pipeline → Build Now**

4. Watch the **Console Output** for live logs.

---

## ✔️ Verify Deployment

After the pipeline succeeds:

```bash
# Check pod status (wait for Running)
kubectl get pods

# Check deployment
kubectl get deployments

# Check service
kubectl get services

# Get the app URL
minikube service java-app-service --url
```

Expected pod output:
```
NAME                        READY   STATUS    RESTARTS   AGE
java-app-85d844586c-vq77c   1/1     Running   0          1m
```

---

## 🐛 Errors & Fixes

### ❌ Error 1 — Minikube Not Reachable

```
dial tcp 192.168.49.2:8443: connect: no route to host
```

**Cause:** Minikube is not running. The virtual network interface only exists while Minikube is active.

**Fix:**
```bash
minikube start
```

---

### ❌ Error 2 — Docker Permission Denied

```
permission denied while trying to connect to the Docker daemon socket
at unix:///var/run/docker.sock
```

**Cause:** The `jenkins` user inside the container doesn't belong to the group that owns the Docker socket on the host.

**Fix (run from host machine):**
```bash
docker exec -u root jenkins bash -c "
  DOCKER_GID=\$(stat -c '%g' /var/run/docker.sock) && \
  groupadd -g \$DOCKER_GID docker_host 2>/dev/null || true && \
  usermod -aG docker_host jenkins
"
docker restart jenkins
```

---

### ❌ Error 3 — withDockerRegistry Not Found

```
No such DSL method 'withDockerRegistry' found among steps
```

**Cause:** The Docker Pipeline plugin is not installed. The original Jenkinsfile used `withDockerRegistry` which requires it.

**Fix:** Replace `withDockerRegistry` with `withCredentials` in the Jenkinsfile (no extra plugin needed):

```groovy
withCredentials([usernamePassword(
    credentialsId: 'dockerhub-creds',
    usernameVariable: 'DOCKER_USER',
    passwordVariable: 'DOCKER_PASS'
)]) {
    sh '''
        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
        docker push $DOCKER_IMAGE
        docker logout
    '''
}
```

---

### ❌ Error 4 — kubeconfig Certificate Not Found

```
unable to read client-cert /home/jenkins/.minikube/profiles/minikube/client.crt
```

**Cause:** The `sed` command inside the Jenkins container modified the shared mounted kubeconfig, corrupting paths on the host machine too (because it's the same file via volume mount).

**Fix (run on host machine):**
```bash
sed -i 's#/home/jenkins#/home/krishna#g' ~/.kube/config
```

---

### ❌ Error 5 — Wrong Docker Image Built

**Cause:** The `Dockerfile` in the repo was the Jenkins Dockerfile (`FROM jenkins/jenkins:lts`) instead of the Java app Dockerfile. This caused `docker build` in the pipeline to build a Jenkins image and push it to DockerHub.

**Fix:** Replace the repo `Dockerfile` with:
```dockerfile
FROM eclipse-temurin:17-jre
COPY target/simple-java-app-1.0.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

---

## 📌 Useful Commands

### Jenkins

```bash
docker start jenkins          # Start Jenkins
docker stop jenkins           # Stop Jenkins
docker restart jenkins        # Restart Jenkins
docker logs jenkins           # View Jenkins logs
docker logs -f jenkins        # Follow live logs
docker exec -it jenkins bash  # Shell into Jenkins container
```

### Minikube

```bash
minikube start                           # Start Minikube
minikube stop                            # Stop Minikube
minikube status                          # Check status
minikube service java-app-service --url  # Get app URL
minikube dashboard                       # Open K8s dashboard
```

### Kubernetes

```bash
kubectl get pods                          # List pods
kubectl get deployments                   # List deployments
kubectl get services                      # List services
kubectl describe pod <pod-name>           # Debug a pod
kubectl logs <pod-name>                   # View pod logs
kubectl delete deployment java-app        # Delete deployment
kubectl delete service java-app-service   # Delete service
```

### Docker

```bash
docker ps                                 # Running containers
docker ps -a                              # All containers
docker images                             # List images
docker rmi srikrishnaedu18docker/java-app # Remove image
docker pull srikrishnaedu18docker/java-app # Pull image
```

---

## 📦 DockerHub Image

The built image is available at:

```
docker pull srikrishnaedu18docker/java-app:latest
```

---

## 👤 Author

**Sri Krishna R**
- GitHub: [srikrishnaedu18-git](https://github.com/srikrishnaedu18-git)
- DockerHub: [srikrishnaedu18docker](https://hub.docker.com/u/srikrishnaedu18docker)
