
# Dockerfile for eBPF development in Azure (Github Codespaces compatible)
FROM ubuntu:24.04

# Install latest dependencies and tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    clang llvm gcc make iproute2 iputils-ping git curl wget ca-certificates \
    linux-headers-6.8.0-1030-azure libbpf-dev \
    netcat-openbsd jq\
    && rm -rf /var/lib/apt/lists/* \
    # Note: this symlink is needed for VMs in Azure for BPF to compile, adjust accordingly for other environments
    && [ -e /usr/include/asm ] || ln -s /usr/include/x86_64-linux-gnu/asm/ /usr/include/asm


# Clone bpftool repo and submodules, checkout v7.6.0, and build
RUN git clone --recurse-submodules https://github.com/libbpf/bpftool.git /tmp/bpftool \
    && cd /tmp/bpftool \
    && git checkout v7.6.0 \
    && make -C src \
    && make -C src install

# Set up working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
