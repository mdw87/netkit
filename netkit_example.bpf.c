
#include <linux/types.h>
#include <bpf/bpf_helpers.h>
#include <linux/ip.h>
#include <linux/tcp.h>
#include <linux/if_ether.h>
#include <linux/pkt_cls.h>
#include <bpf/bpf_endian.h>

SEC("netkit/peer")
int netkit_peer_prog(struct __sk_buff *skb)
{
    struct iphdr ip;
    struct tcphdr tcp;

    // Load IP header
    if (0 != bpf_skb_load_bytes(skb, sizeof(struct ethhdr), &ip, sizeof(struct iphdr)))
    {
        bpf_printk("bpf_skb_load_bytes iph failed");
        return TC_ACT_OK;
    }

    // Load TCP header
    if (0 != bpf_skb_load_bytes(skb, sizeof(struct ethhdr) + (ip.ihl << 2), &tcp, sizeof(struct tcphdr)))
    {
        bpf_printk("bpf_skb_load_bytes ethh failed");
        return TC_ACT_OK;
    }

    // Get port numbers
    unsigned int src_port = bpf_ntohs(tcp.source);
    unsigned int dst_port = bpf_ntohs(tcp.dest);

    // Check if destination port is 12345
    if (src_port == 12345) {
        // Drop the packet
        bpf_printk("Dropping packet to port 12345 from port %d", src_port);
        return TC_ACT_SHOT;
    }

    // Allow the packet
    bpf_printk("Allowing packet to port %d from port %d", dst_port, src_port);
    return TC_ACT_OK;
}

char _license[] SEC("license") = "GPL";