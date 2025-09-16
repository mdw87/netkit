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

#### Setting up the Docker container

To compile and attach the BPF program, some dependencies are needed. I have provided a dockerfile to make it easier to get everything set up. You may need to modify the dockerfile according to your environment. The provided file was tested on a Github Codespaces machine, which is a VM running in Azure.

Build and run the Docker image:
```
docker build -t netkit-dev .
docker run --rm -it --cap-add=SYS_ADMIN --cap-add=SYS_RESOURCE --cap-add=NET_ADMIN -v "$PWD":/workspace -w /workspace netkit-dev
```

### Setting up the Network Namepsace and Netkit Device

Create a new network namespace

`ip netns add task_netns`

Create the netkit device

`ip link add task_nk type netkit`

Note that two netkit devices (primary and peer) have been created in `ip -d link show` output

```
ip -d link show
...
6: nk0@task_nk: <BROADCAST,MULTICAST,NOARP,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff promiscuity 0  allmulti 0 minmtu 68 maxmtu 65535 
--->netkit addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 tso_max_size 524280 tso_max_segs 65535 gro_max_size 65536 
7: task_nk@nk0: <BROADCAST,MULTICAST,NOARP,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff promiscuity 0  allmulti 0 minmtu 68 maxmtu 65535 
--->netkit addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 tso_max_size 524280 tso_max_segs 65535 gro_max_size 65536 
```

Move the peer end into the new network namespace

`ip link set task_nk netns task_netns`

Now note that when we run `ip -d link show` on the host netns, the peer is no longer visible. But it is there if we run the same command in the task_netns:

```
ip -d link show
...
1: lo
2: eth0
3: docker0
6: nk0@if7

ip netns exec task_netns ip link show
1: lo
7: task_nk@if6
```

Let's do some basic network configuration now

```shell
# Configure the task netkit device
ip netns exec task_netns ip addr add 10.0.0.2/24 dev task_nk
ip netns exec task_netns ip link set task_nk up
# Configure the host netkit device
ip addr add 10.0.0.1/24 dev nk0
ip link set nk0 up
```

Now, we should be able to ping our new network:

```bash
# I had to install ping to my code-space, you may already have it
apt-get update -y
apt-get install -y iputils-ping
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
# Start up nc listening in the task_netns
ip netns exec task_netns nc -l -p 12345 &
# connect to the listening, server and send a message
nc 10.0.0.2 12345
Hello!
```

## Adding a BPF Program to the Netkit device

The performance benefit of Netkit comes from its ability to intercept packets from the container network namespace, and take actions such as redirecting or dropping the packet in a BPF program. This section will walk through creating a simple program that drops any packet with port 12345, and attaching it to the peer device (where it will run on packets leaving the network namespace).

The contents of this simple BPF program have been provided in `netkit_sample.bpf.c`. This BPF program
checks the port of the packet passing through the program, and drops it if the port is 12345.

Build the BPF program using clang:
```
clang -g -O2 -c -target bpf -o netkit_example.o netkit_example.bpf.c
```

Building the BPF program will generate a .o file. This file can now be loaded into the kernel:
```
bpftool prog load netkit_example.o /sys/fs/bpf/netkit_example
```

Having loaded the program, it can now be attached to the netkit device:
```
bpftool prog show | grep netkit
(note the prog ID in output)
bpftool net attach tc id <ID> dev nk0
```

Verify the prog is attached:
```
bpftool net show
...
tc:
nk0(3) tcx/ingress netkit_peer_prog prog_id 180 
```

Now, observe that when setting up a connection on port 12345, the message will be dropped:
```
ip netns exec task_netns nc -l -p 12345 &
[1] 32
root@a09fdbf1c5e0:/workspace# nc 10.0.0.2 12345
Hello!
^C
```

However, using port 12346, the message will go through:
```
ip netns exec task_netns nc -l -p 12346 &
[2] 34
root@a09fdbf1c5e0:/workspace# nc 10.0.0.2 12346
Hello!
Hello!
^C
```

Note, this command will detach the filter:
```
bpftool net detach dev nk0 tc
```

So there you have it! We have successfully demonstrated:
- Creating an isolated network environment using Network Namespaces
- Creating a connection to our isolated network using Netkit
- Adding a simple BPF program to filter network traffic 

#### Note on debugging

To see what is going on in the BPF program, it is helpful to use `bpf_printk`
statements. To get these working:
```
# Mount the debugfs
sudo mount -t debugfs none /sys/kernel/debug

# Start echoing the debug statments
sudo cat /sys/kernel/debug/tracing/trace_pipe
```

Now you will see the `bpf_printk` messages. In another terminal, test your
network connection and you should see messages for "Allowing packet" and "Dropping packet"