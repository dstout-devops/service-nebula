ARG VARIANT=trixie

FROM scratch AS certs
COPY certificates/* .

FROM mcr.microsoft.com/vscode/devcontainers/base:${VARIANT} AS apt
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
    && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man

COPY --from=certs * /usr/local/share/ca-certificates/mc/
RUN update-ca-certificates

RUN mkdir -p -m 755 /etc/apt/keyrings && \
    # kubernetes
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list && \
    chmod 644 /etc/apt/sources.list.d/kubernetes.list && \
    # hashicorp
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashi-apt-keyring.gpg && \
    chmod 644 /etc/apt/keyrings/hashi-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/hashi-apt-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashi-stable-debian.list && \
    # helm
    curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor -o /etc/apt/keyrings/helm-apt-keyring.gpg && \
    chmod 644 /etc/apt/keyrings/helm-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/helm-apt-keyring.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list && \
    # step
    curl -fsSL https://packages.smallstep.com/keys/apt/repo-signing-key.gpg | gpg --dearmor -o /etc/apt/keyrings/smallstep-apt-keyring.gpg && \
    echo 'deb [signed-by=/etc/apt/keyrings/smallstep-apt-keyring.gpg] https://packages.smallstep.com/stable/debian debs main' | tee /etc/apt/sources.list.d/smallstep.list

FROM mcr.microsoft.com/devcontainers/go:${VARIANT} AS devcontainer
ENV DEBIAN_FRONTEND=noninteractive

COPY --from=certs * /usr/local/share/ca-certificates/mc/
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && update-ca-certificates

COPY --from=apt /etc/apt/keyrings /etc/apt/keyrings
COPY --from=apt /etc/apt/sources.list.d /etc/apt/sources.list.d
RUN apt-get update \
    && apt-get install -y \
        helm \
        kubectl kubectx \
        step-ca step-cli \
    && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man

COPY --from=hashicorp/vault:latest /bin/vault /bin/
COPY --from=ghcr.io/opentofu/opentofu:minimal /usr/local/bin/tofu /usr/local/bin/
COPY --from=docker.io/alpine/terragrunt:latest /usr/local/bin/terragrunt /usr/local/bin/

ADD https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.deb /tmp/k9s.deb
RUN apt-get install -y /tmp/k9s.deb && rm /tmp/k9s.deb
