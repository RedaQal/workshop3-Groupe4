FROM jenkins/jenkins:lts-jdk21

USER root

# System tools: Python (for Semgrep), Node.js 20 (Next.js build)
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl unzip ca-certificates gnupg python3 python3-venv python3-pip \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI (official static binary, independent of the Debian version)
ARG DOCKER_VERSION=27.3.1
RUN curl -fsSL "https://download.docker.com/linux/static/stable/$(uname -m)/docker-${DOCKER_VERSION}.tgz" \
    | tar -xz --strip-components=1 -C /usr/local/bin docker/docker

# SonarScanner CLI
ARG SONAR_SCANNER_VERSION=6.2.1.4610
RUN curl -fsSL -o /tmp/sonar-scanner.zip \
      https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip \
    && unzip -q /tmp/sonar-scanner.zip -d /opt \
    && mv /opt/sonar-scanner-* /opt/sonar-scanner \
    && ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner \
    && rm /tmp/sonar-scanner.zip

# Semgrep (in a venv to avoid conflicts with system Python)
RUN python3 -m venv /opt/semgrep \
    && /opt/semgrep/bin/pip install --no-cache-dir semgrep \
    && ln -s /opt/semgrep/bin/semgrep /usr/local/bin/semgrep

USER jenkins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt

# OWASP Dependency-Check CLI
ARG DEPCHECK_VERSION=11.1.0
RUN curl -fsSL -o /tmp/dc.zip \
      https://github.com/jeremylong/DependencyCheck/releases/download/v${DEPCHECK_VERSION}/dependency-check-${DEPCHECK_VERSION}-release.zip \
    && unzip -q /tmp/dc.zip -d /opt \
    && chmod +x /opt/dependency-check/bin/dependency-check.sh \
    && ln -s /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check.sh \
    && rm /tmp/dc.zip