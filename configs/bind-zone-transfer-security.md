# BIND DNS Server — Zone Transfer Security Configuration

## Overview

This reference covers BIND 9 (`named`) configuration for securing zone transfers and hardening a DNS server. Apply these settings to your DNS server's `/etc/named.conf` or `/etc/bind/named.conf`.

---

## 1. Disable Zone Transfers (Recommended Default)

If you have no secondary DNS servers, disable zone transfers entirely:

```
// /etc/named.conf or /etc/bind/named.conf.options

options {
    // Disable zone transfers globally — no server gets our zone data
    allow-transfer { none; };

    // Only allow queries from your own network
    allow-query { any; };           // for public authoritative server
    // allow-query { 192.168.1.0/24; };  // for internal DNS only

    // Disable recursion on authoritative servers
    recursion no;
};
```

---

## 2. Restrict Zone Transfers to Secondary NS Only

If you have a secondary name server at `192.0.2.10`:

```
// Per-zone restriction (overrides global setting)
zone "yourdomain.com" {
    type master;
    file "/var/named/yourdomain.com.zone";

    // Only allow your secondary to transfer
    allow-transfer { 192.0.2.10; };

    // Notify secondary when zone is updated
    also-notify { 192.0.2.10; };
    notify yes;
};

// On the secondary server
zone "yourdomain.com" {
    type slave;
    masters { 192.0.2.1; };         // IP of your primary server
    file "/var/named/slaves/yourdomain.com.zone";
    allow-transfer { none; };        // secondary should not transfer to others
};
```

---

## 3. TSIG — Transaction Signature Authentication

TSIG adds HMAC-based authentication to zone transfers. Even if an attacker knows your secondary's IP, they cannot complete a transfer without the shared key.

### Generate a TSIG Key

```bash
# Method 1: tsig-keygen (BIND 9.9+)
tsig-keygen -a hmac-sha256 zone-transfer-key

# Method 2: dnssec-keygen
dnssec-keygen -a HMAC-SHA256 -b 256 -n HOST zone-transfer-key
# Creates: Kzone-transfer-key.+163+XXXXX.key and .private

# Method 3: openssl
openssl rand -base64 32
# Use the output as the secret value below
```

### Configure TSIG Key in BIND

```
// Key definition — same on both primary and secondary
key "zone-transfer-key" {
    algorithm hmac-sha256;
    secret "7yCgxlvMgOp3RRtbRBvClpvFTm9Qs7xwHmI8oACdZoU=";
};

// Apply to zone (primary)
zone "yourdomain.com" {
    type master;
    file "/var/named/yourdomain.com.zone";
    allow-transfer { key zone-transfer-key; };
};

// On secondary: use the key when requesting transfers
server 192.0.2.1 {
    keys { zone-transfer-key; };
};
```

### Testing TSIG-Authenticated Transfer

```bash
# Transfer with TSIG key from command line
dig axfr @primary-ns.yourdomain.com yourdomain.com \
    -k /path/to/Kzone-transfer-key.+163+XXXXX.private

# Should work with valid key
# Should return REFUSED without key
```

---

## 4. Split DNS (View Configuration)

Serve different zone data to internal vs external clients:

```
// ACL definitions
acl "internal" {
    10.0.0.0/8;
    192.168.0.0/16;
    172.16.0.0/12;
    127.0.0.1;
};

acl "external" {
    any;
};

// Internal view — full zone with all records
view "internal" {
    match-clients { internal; };
    recursion yes;

    zone "company.com" {
        type master;
        file "/var/named/company-internal.zone";
        allow-transfer { none; };
    };
};

// External view — public-only records
view "external" {
    match-clients { external; };
    recursion no;

    zone "company.com" {
        type master;
        file "/var/named/company-external.zone";
        allow-transfer { none; };
    };
};
```

**Internal zone file includes:**
```
; company-internal.zone — includes everything
$ORIGIN company.com.
@            IN  SOA   ns1 admin ( 2024010101 3600 900 604800 300 )
@            IN  NS    ns1.company.com.
@            IN  A     203.0.113.10           ; public website
mail         IN  A     203.0.113.20           ; public mail server
intranet     IN  A     10.0.0.50              ; INTERNAL ONLY
db01         IN  A     10.0.1.10              ; INTERNAL ONLY
vpn          IN  A     203.0.113.30           ; VPN server
dc01         IN  A     10.0.0.10              ; INTERNAL ONLY
```

**External zone file includes (public only):**
```
; company-external.zone — public records only
$ORIGIN company.com.
@            IN  SOA   ns1 admin ( 2024010101 3600 900 604800 300 )
@            IN  NS    ns1.company.com.
@            IN  A     203.0.113.10           ; public website
mail         IN  A     203.0.113.20           ; public mail server
; Internal records NOT included
```

---

## 5. Response Rate Limiting (DDoS Amplification Protection)

DNS amplification attacks use open resolvers to amplify traffic. RRL limits how often the same response is sent.

```
options {
    rate-limit {
        responses-per-second 10;
        window 5;
        log-only no;
    };
};
```

---

## 6. Firewall Rules

```bash
# Allow DNS queries from anywhere (public authoritative server)
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT

# BUT: restrict TCP-53 (zone transfers) to secondary NS only
iptables -A INPUT -p tcp --dport 53 ! -s 192.0.2.10 -j DROP

# Using ufw (Ubuntu)
ufw allow 53/udp
ufw allow from 192.0.2.10 to any port 53 proto tcp
ufw deny 53/tcp

# Check rules
iptables -L -n -v | grep 53
```

---

## 7. Verification Checklist

```bash
# Check zone transfer is blocked from random IP
dig axfr @your-ns.yourdomain.com yourdomain.com
# Should return: Transfer failed. (REFUSED)

# Check zone transfer works from authorised secondary
dig axfr @your-ns.yourdomain.com yourdomain.com -k tsig.key
# Should return: full zone data

# Check BIND config syntax
named-checkconf /etc/named.conf

# Check zone file syntax
named-checkzone yourdomain.com /var/named/yourdomain.com.zone

# Test TSIG key is working
dig @your-ns.yourdomain.com yourdomain.com SOA \
    -k /etc/bind/tsig.key

# Verify split DNS (internal vs external)
# From inside your network:
dig @internal-ns intranet.company.com
# Should return internal IP

# From outside (simulated):
dig @external-ns intranet.company.com
# Should return NXDOMAIN
```

---

## Security Hardening Checklist

```
[ ] allow-transfer { none; }  set globally
[ ] Per-zone allow-transfer restricts to secondary NS IPs only
[ ] TSIG keys configured and tested
[ ] Zone transfer works from authorised secondary
[ ] Zone transfer refused from all other IPs
[ ] Recursion disabled on authoritative servers
[ ] Split DNS configured (internal ≠ external)
[ ] Firewall blocks TCP-53 except from secondary
[ ] BIND logs reviewed regularly
[ ] DNSSEC signed zones (if supported)
[ ] named-checkconf passes without warnings
[ ] named-checkzone passes for all zones
```
