#!/bin/bash

# 1. Create network namespace
ip netns add task_netns

# 2. Create netkit device
ip link add task_nk type netkit

# 3. Move peer end into the new network namespace
ip link set task_nk netns task_netns

# 4. Configure the task netkit device
ip netns exec task_netns ip addr add 10.0.0.2/24 dev task_nk
ip netns exec task_netns ip link set task_nk up

# 5. Configure the host netkit device
ip addr add 10.0.0.1/24 dev nk0
ip link set nk0 up

# 6. Test connectivity
ping -c 3 10.0.0.2 || true
