# Run this script to install bpftool from source

git clone --recurse-submodules https://github.com/libbpf/bpftool.git /tmp/bpftool
cd /tmp/bpftool
git checkout v7.6.0
make -C src
sudo make -C src install