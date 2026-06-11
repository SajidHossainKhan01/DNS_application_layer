# DNS Zone Transfer — Concepts, Lab & Security

## What is a Zone Transfer?

A **DNS zone transfer** is the process of replicating DNS zone data (all DNS records for a domain) from a **Primary (Master)** server to one or more **Secondary (Slave)** servers.

Zone transfers are a core DNS feature designed to ensure:
- **Redundancy** — if the primary server goes down, secondaries can still answer queries
- **Load balancing** — distribute query load across multiple servers
- **Geographic distribution** — place servers close to users worldwide
- **Fault tolerance** — continued DNS service during maintenance

---

## Zone Transfer Types

| Type | Name | Description | Use Case |
|------|------|-------------|---------|
| **AXFR** | Full Zone Transfer | Copies the **entire** zone file | Initial sync, recovery |
| **IXFR** | Incremental Zone Transfer | Copies only **changes** since the last sync (using serial number) | Ongoing updates |

### How the Sync Process Works

```
Secondary Server                      Primary Server
      │                                     │
      │  1. Query SOA record                │
      │ ──────────────────────────────────► │
      │                                     │
      │  2. Compare serial numbers          │
      │ ◄────────────────────────────────── │
      │                                     │
      │  If primary serial > secondary:     │
      │  3. Request AXFR or IXFR            │
      │ ──────────────────────────────────► │
      │                                     │
      │  4. Zone data transferred           │
      │ ◄────────────────────────────────── │
      │                                     │
      │  5. Secondary updates its records   │
      │                                     │
```

The **SOA serial number** is the version stamp for the zone. Every time a record is changed on the primary, the serial number is incremented. The secondary compares serials to decide if a transfer is needed.

---

## Zone Transfer Lab Exercise

This lab uses `zonetransfer.me` — a domain intentionally misconfigured to allow public zone transfers for **educational demonstration** purposes.

**Credit:** Digi.ninja — https://digi.ninja/projects/zonetransferme.php

### Step 1 — Resolve the Domain

```bash
# Verify the domain resolves correctly
dig @1.1.1.1 zonetransfer.me A +short
```

### Step 2 — Find the Authoritative Name Servers

```bash
# Verbose NS lookup
dig -t NS @1.1.1.1 zonetransfer.me

# Short output — just the NS names
dig -t NS +short @1.1.1.1 zonetransfer.me
```

**Expected output:**
```
nsztm1.digi.ninja.
nsztm2.digi.ninja.
```

### Step 3 — Request Full Zone Transfer (AXFR)

```bash
# Attempt zone transfer from the first NS
dig axfr @nsztm1.digi.ninja zonetransfer.me

# Try the second NS
dig axfr @nsztm2.digi.ninja zonetransfer.me
```

### Step 4 — Analyse What Was Exposed

A successful zone transfer reveals the **entire DNS zone**, including:

```
; Partial output from zonetransfer.me AXFR:
zonetransfer.me.         7200  IN  SOA   nsztm1.digi.ninja. ...
zonetransfer.me.         300   IN  A     5.196.105.14
zonetransfer.me.         300   IN  MX 0  ASPMX.L.GOOGLE.COM.
zonetransfer.me.         300   IN  NS    nsztm1.digi.ninja.
admin.zonetransfer.me.   300   IN  A     5.196.105.14        ← internal host
email.zonetransfer.me.   300   IN  A     74.125.206.26       ← mail server IP
internal.zonetransfer.me.300   IN  A     192.168.100.1       ← PRIVATE IP!
office.zonetransfer.me.  300   IN  A     4.23.39.254         ← office network
vpn.zonetransfer.me.     300   IN  A     174.36.59.154       ← VPN server!
staging.zonetransfer.me. 300   IN  CNAME www.zonetransfer.me.
dc.zonetransfer.me.      300   IN  A     5.196.105.14        ← domain controller!
```

**What an attacker learns from this:**
- Complete internal network structure
- Private IP ranges in use
- All server names and their roles
- VPN and remote access endpoints
- Email infrastructure
- Staging and development systems
- Any third-party service dependencies

### Step 5 — Incremental Transfer

```bash
# IXFR — request only changes since serial 1
dig @nsztm1.digi.ninja zonetransfer.me IXFR=1
```

---

## Security Risks

### Information Disclosure

An open zone transfer gives attackers a **complete map of your infrastructure** in a single query. This dramatically reduces the reconnaissance effort required to plan an attack.

**Attack scenarios enabled by zone transfer data:**
1. Target the VPN server for brute-force attacks
2. Identify the domain controller for lateral movement planning  
3. Find staging servers (often less hardened than production)
4. Map private IP ranges for network scanning after initial access
5. Identify all mail servers to plan phishing infrastructure

### Who Attempts Zone Transfers?

- **Penetration testers** — legitimate infrastructure mapping
- **Bug bounty hunters** — discovering exposed infrastructure
- **Threat actors** — planning targeted attacks
- **Automated scanners** — tools like `dnsrecon`, `fierce`, `dnsenum`

---

## Mitigation Controls

### 1. Restrict Zone Transfers in BIND

```
# /etc/named.conf — most important control

zone "yourdomain.com" {
    type master;
    file "/var/named/yourdomain.com.zone";

    # Allow only your secondary NS server
    allow-transfer { 192.0.2.10; };

    # OR: disable entirely if no secondary needed
    allow-transfer { none; };
};
```

### 2. TSIG — Transaction Signature Authentication

Authenticates zone transfers using a shared HMAC secret key.

```
# Generate a TSIG key
tsig-keygen -a hmac-sha256 transfer-key > /etc/bind/transfer.key

# Key file contents:
key "transfer-key" {
    algorithm hmac-sha256;
    secret "base64encodedsecrethere==";
};

# Apply in zone config
zone "yourdomain.com" {
    type master;
    allow-transfer { key transfer-key; };
};
```

### 3. Monitor DNS Logs

```bash
# Check for AXFR attempts in BIND logs
grep "AXFR" /var/log/named/default.log

# Or monitor with journald
journalctl -u named | grep -i "axfr\|transfer"
```

### 4. Firewall Rules

```bash
# Block inbound zone transfer requests on port 53/TCP from untrusted sources
iptables -A INPUT -p tcp --dport 53 ! -s 192.0.2.10 -j DROP

# On the authoritative server, only allow TCP-53 from secondary NS
ufw allow from 192.0.2.10 to any port 53 proto tcp
ufw deny 53/tcp
```

### 5. Split DNS (Horizon DNS)

Configure different DNS responses for internal vs external queries:
- **Internal DNS**: full zone with all records (only accessible inside the network)
- **External DNS**: minimal records (only what external users need to reach public services)

```
# BIND view configuration for split DNS
view "internal" {
    match-clients { 10.0.0.0/8; 192.168.0.0/16; };
    zone "company.com" {
        type master;
        file "/var/named/company-internal.zone";  # full records
    };
};

view "external" {
    match-clients { any; };
    zone "company.com" {
        type master;
        file "/var/named/company-external.zone";  # public-only records
    };
};
```

---

## Mitigation Summary Table

| Control | Priority | Effort | Effect |
|---------|---------|--------|--------|
| `allow-transfer { none; }` | 🔴 Critical | Low | Blocks all AXFR/IXFR |
| TSIG key authentication | 🔴 Critical | Medium | Authenticates legitimate transfers |
| Firewall TCP-53 restriction | 🟡 High | Low | Network-level block |
| DNS log monitoring / SIEM | 🟡 High | Medium | Detects attempts |
| Split DNS | 🟢 Good | High | Limits external exposure |
| Network segmentation (DMZ) | 🟢 Good | High | Isolates DNS servers |
