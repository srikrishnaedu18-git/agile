FROM jenkins/jenkins:lts

USER root

# Install Docker + kubectl
RUN apt-get update && \
    apt-get install -y docker.io curl && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Add Jenkins user to docker group
RUN usermod -aG docker jenkins

USER jenkins