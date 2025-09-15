
# Dockerfile for eBPF development in Azure (Github Codespaces compatible)
FROM ubuntu:24.04

# Install latest dependencies and tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    clang llvm gcc make iproute2 iputils-ping git curl wget ca-certificates \
    linux-headers-6.8.0-1030-azure libbpf-dev \
    # For bpftool
    linux-tools-common linux-tools-generic linux-tools-$(uname -r) \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/src/linux-headers-6.8.0-1030-azure/include/asm \
    # Note: this is needed for VMs in Azure for BPF to compile, adjust accordingly for other environments
    && ln -s /usr/include/x86_64-linux-gnu/asm/ /usr/include/asm

# Set up working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
