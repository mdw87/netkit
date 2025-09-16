#!/bin/bash
set -e

# 1. Detach the filter from nk0
echo "Detaching BPF filter from nk0..."
bpftool net detach dev tc nk0

# 2. Remove the pinned BPF object
echo "Removing pinned BPF object..."
rm /sys/fs/bpf/netkit_example

# 3. Rebuild the BPF program
echo "Rebuilding BPF program..."
clang -g -O2 -c -target bpf -o netkit_example.o netkit_example.bpf.c

# 4. Load the BPF program
echo "Loading BPF program..."
bpftool prog load netkit_example.o /sys/fs/bpf/netkit_example

# 5. Get the program ID
echo "Getting BPF program ID..."
PROG_ID=$(bpftool prog list -j | jq '.[] | select(.name == "netkit_peer_prog") | .id')
echo "Program ID: $PROG_ID"

# 6. Attach the program to nk0 (tc hook 214)
echo "Attaching BPF program to nk0..."
sudo bpftool net attach tc id $PROG_ID dev nk0

echo "Done."
