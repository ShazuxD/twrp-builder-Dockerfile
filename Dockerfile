FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    sudo \
    nano \
    wget \
    kmod \
    mergerfs \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash twrp-builder \
    && usermod -aG sudo twrp-builder \
    && echo "twrp-builder ALL=(ALL) NOPASSWD:ALL" \
       > /etc/sudoers.d/twrp-builder \
    && chmod 0440 /etc/sudoers.d/twrp-builder

RUN echo 'export PS1="\[\033[1;32m\]@twrp-builder\[\033[0m\] ➜ \[\033[1;34m\]\w\[\033[0m\] \$ "' \
    >> /home/twrp-builder/.bashrc \
    && chown twrp-builder:twrp-builder /home/twrp-builder/.bashrc

COPY merge-storage.sh /usr/local/bin/merge-storage

RUN chmod +x /usr/local/bin/merge-storage

WORKDIR /twrp

USER twrp-builder
