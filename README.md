# netkit
Samples and resources for learning about the netkit container networking device

## Resources
Visit the following links to learn more about the netkit device:

- [Cilium netkit: The Final Frontier in Container Networking Performance](https://isovalent.com/blog/post/cilium-netkit-a-new-container-networking-paradigm-for-the-ai-era/)
- [An Introduction to Netkit: The BPF Programmable Network Device](https://fosdem.org/2025/schedule/event/fosdem-2025-4045-an-introduction-to-netkit-the-bpf-programmable-network-device/)
- [Introduction to Linux Netkit interfaces — with a grain of eBPF
](https://blog.yadutaf.fr/2025/07/01/introduction-to-linux-netkit-interfaces-with-a-grain-of-ebpf/)

## Getting started with Netkit

### Setting up a Netkit device using command line tools

These instructions will walk you through creating a new network namespace, adding a Netkit interface, and attaching a simple BPF progam to the interface.

These steps were developed and tested using a Github Codespaces machine running on Azure. To open a Github codespace, from the repo homepage, click the green "<>Code" button, then the codespaces tab. Once in the online editor, use ctrl+` to launch a terminal.

Create a new network namespace

`sudo ip netns add task_netns`

Create the netkit device

`sudo ip link add task_nk type netkit`

Note that two netkit devices (primary and peer) have been created in `ip -d link show` output

```
sudo ip -d link show
...
6: nk0@task_nk: <BROADCAST,MULTICAST,NOARP,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff promiscuity 0  allmulti 0 minmtu 68 maxmtu 65535 
--->netkit addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 tso_max_size 524280 tso_max_segs 65535 gro_max_size 65536 
7: task_nk@nk0: <BROADCAST,MULTICAST,NOARP,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff promiscuity 0  allmulti 0 minmtu 68 maxmtu 65535 
--->netkit addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 tso_max_size 524280 tso_max_segs 65535 gro_max_size 65536 
```

Move the peer end into the new network namespace

`sudo ip link set task_nk@nk0 netns task_netns`

Now note that when we run `ip -d link show` on the host netns, the peer is no longer visible. But it is there if we run the same command in the task_netns:

```
sudo ip -d link show
...
1: lo
2: eth0
3: docker0
6: nk0@if7

sudo ip netns exec task_netns ip link show
1: lo
7: task_nk@if6
```

Let's do some basic network configuration now

```shell
# Configure the task netkit device
sudo ip netns exec task_netns ip addr add 10.0.0.2/24 dev task_nk
sudo ip netns exec task_netns ip link set task_nk up
# Configure the host netkit device
sudo ip addr add 10.0.0.1/24 dev nk0
sudo ip link set nk0 up
```

Now, we should be able to ping our new network:

```bash
# I had to install ping to my code-space, you may already have it
sudo apt-get update -y
sudo apt-get install -y iputils-ping
ping -c 6 10.0.0.2
PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=0.032 ms
64 bytes from 10.0.0.2: icmp_seq=2 ttl=64 time=0.030 ms
64 bytes from 10.0.0.2: icmp_seq=3 ttl=64 time=0.024 ms
64 bytes from 10.0.0.2: icmp_seq=4 ttl=64 time=0.037 ms
64 bytes from 10.0.0.2: icmp_seq=5 ttl=64 time=0.029 ms
64 bytes from 10.0.0.2: icmp_seq=6 ttl=64 time=0.024 ms

--- 10.0.0.2 ping statistics ---
6 packets transmitted, 6 received, 0% packet loss, time 5121ms
rtt min/avg/max/mdev = 0.024/0.029/0.037/0.004 ms
```

For good measure, let's start a server in the container and check that we can reach it from the host:
```
sudo apt install -y netcat-openbsd
