FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server rsyslog sudo curl gnupg ca-certificates \
    && mkdir -p /run/sshd \
    && rm -rf /var/lib/apt/lists/*

# Compte de test utilisé uniquement dans le laboratoire
RUN useradd -m -s /bin/bash demo \
    && echo 'demo:password123' | chpasswd \
    && usermod -aG sudo demo

COPY sshd_config /etc/ssh/sshd_config

EXPOSE 22

CMD ["/bin/bash", "-c", "/usr/sbin/rsyslogd && exec /usr/sbin/sshd -D -e"]