FROM jenkins/jenkins:lts

USER root

# Install Docker
RUN apt-get update && \
    apt-get install -y docker.io

# Install kubectl
RUN apt-get update && \
    apt-get install -y kubectl

RUN usermod -aG docker jenkins

USER jenkins