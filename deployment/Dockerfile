# syntax=docker/dockerfile:1
ARG BASE_IMAGE=private-registry.nginx.com/nap/waf-compiler:5.13.4
FROM ${BASE_IMAGE}

# Installing packages as root
USER root

ENV DEBIAN_FRONTEND="noninteractive"

RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
    --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
    apt-get update \
    && apt-get install -y \
        apt-transport-https \
        lsb-release \
        ca-certificates \
        wget \
        gnupg2 \
        ubuntu-keyring \
    && wget -qO - https://cs.nginx.com/static/keys/app-protect-security-updates.key | gpg --dearmor | \
    tee /usr/share/keyrings/app-protect-security-updates.gpg >/dev/null \
    && printf "deb [signed-by=/usr/share/keyrings/app-protect-security-updates.gpg] \
    https://pkgs.nginx.com/app-protect-security-updates/ubuntu `lsb_release -cs` nginx-plus\n" | \
    tee /etc/apt/sources.list.d/nginx-app-protect.list \
    && wget -P /etc/apt/apt.conf.d https://cs.nginx.com/static/files/90pkgs-nginx \
    && apt-get update \
    && apt-get install -y \
        app-protect-attack-signatures \
        app-protect-bot-signatures \
        app-protect-threat-campaigns \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# non-root default user (UID 101)
USER nginx
