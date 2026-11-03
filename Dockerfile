FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    sudo \
    nano \
    wget \
    kmod \
    git \
    mergerfs \
    python-is-python3 \
    unzip \
    tar \
    pigz \
    rclone \
    aria2 \
    ccache \
    snapd \
    python3 \
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

RUN git config --global user.name "ShazuxD" &&git config --global user.email "shazuxd7@gmail.com" &&git config --global core.editor nano

COPY merge-storage.sh /usr/local/bin/merge-storage

COPY swap.sh /usr/local/bin/setup-swap

RUN chmod +x /usr/local/bin/merge-storage

RUN chmod +x /usr/local/bin/setup-swap

RUN cat <<'EOF' >> /home/twrp-builder/.bashrc

# Auto-mount merged storage
if [ -t 0 ] && ! mountpoint -q /twrp; then
    sudo /usr/local/bin/merge-storage
fi

# Enter project directory
if [ -d /twrp/Codespace-TWRP-Builder ]; then
    cd /twrp/Codespace-TWRP-Builder
fi
EOF

RUN chown twrp-builder:twrp-builder /home/twrp-builder/.bashrc

RUN git clone https://github.com/ghostrider-reborn/scripts.git && cd scripts && chmod +x ubuntu-setup.sh && sudo ./ubuntu-setup.sh && cd .. &&rm -rf scripts

WORKDIR /twrp

USER twrp-builder
