FROM ubuntu:22.04

WORKDIR /app

COPY . .

RUN chmod 600 ow-gcp-key

ENV DEBIAN_FRONTEND=noninteractive

# Install required packages and clone repository
RUN apt-get update && \
    apt-get install -y git curl nano vim zip && \
    curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh && \
    chmod +x install-opentofu.sh && \
    ./install-opentofu.sh --install-method deb && \
    rm install-opentofu.sh 

RUN apt-get install -y python3 python3-pip

RUN pip3 install ansible && pip3 install PyYAML && pip3 install jinja2 && pip3 install locust

RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh && rm get_helm.sh