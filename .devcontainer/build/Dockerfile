ARG VARIANT=trixie

FROM mcr.microsoft.com/vscode/devcontainers/base:${VARIANT} AS apt
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \ 
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg && \
    rm -rf /var/lib/apt/lists/*
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    # kubernetes
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list && \
    chmod 644 /etc/apt/sources.list.d/kubernetes.list && \
    # helm
    curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor -o /etc/apt/keyrings/helm-apt-keyring.gpg && \
    chmod 644 /etc/apt/keyrings/helm-apt-keyring.gpg && \
    echo "deb [signed-by=//etc/apt/keyrings/helm-apt-keyring.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list && \
    # step
    curl -fsSL https://packages.smallstep.com/keys/apt/repo-signing-key.gpg | gpg --dearmor -o /etc/apt/keyrings/smallstep-apt-keyring.gpg && \
    echo 'deb [signed-by=/etc/apt/keyrings/smallstep-apt-keyring.gpg] https://packages.smallstep.com/stable/debian debs main' | tee /etc/apt/sources.list.d/smallstep.list

FROM mcr.microsoft.com/devcontainers/go:${VARIANT} AS devcontainer

ENV DEBIAN_FRONTEND=noninteractive

COPY --from=apt /etc/apt/keyrings /etc/apt/keyrings
COPY --from=apt /etc/apt/sources.list.d /etc/apt/sources.list.d

RUN apt-get update && \ 
    apt-get install -y \
        helm \
        kubectl \
        step && \
    rm -rf /var/lib/apt/lists/*
