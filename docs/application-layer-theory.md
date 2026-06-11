# Application Layer — Theory Deep-Dive

## The OSI Model

The **Open Systems Interconnection (OSI)** model is a conceptual framework that divides network communication into seven distinct layers. Each layer has a specific responsibility and only communicates with the layers directly above and below it.

```
┌─────────────────────────────────────────────────────┐
│  Layer 7 — Application   HTTP, DNS, SMTP, FTP, SSH  │ ◄── User-facing
├─────────────────────────────────────────────────────┤
│  Layer 6 — Presentation  SSL/TLS, JPEG, MPEG        │
├─────────────────────────────────────────────────────┤
│  Layer 5 — Session       NetBIOS, PPTP              │
├─────────────────────────────────────────────────────┤
│  Layer 4 — Transport     TCP, UDP                   │
├─────────────────────────────────────────────────────┤
│  Layer 3 — Network       IP, ICMP, ARP              │
├─────────────────────────────────────────────────────┤
│  Layer 2 — Data Link     Ethernet, Wi-Fi (802.11)   │
├─────────────────────────────────────────────────────┤
│  Layer 1 — Physical      Cables, radio waves        │ ◄── Hardware
└─────────────────────────────────────────────────────┘
```

---

## Layer 7 — Application Layer

The **Application Layer** is the topmost layer and the only one that directly interacts with end-user software. It does **not** refer to the application itself (e.g., Chrome, Outlook), but rather the **protocols and services** those applications use to communicate over the network.

### Key Responsibilities

| Responsibility | Description |
|----------------|-------------|
| **Network Service Access** | Acts as the interface for end-user applications to access network services like email, remote login, and file sharing |
| **Resource Sharing** | Facilitates distributed database access and global information lookup (directory services) |
| **Identifying Partners** | Determines the identity and availability of communication partners for a transmission |
| **Protocol Syntax** | Defines the format, semantics, and synchronisation required for software-to-software communication |

---

## Common Application Layer Protocols

### HTTP / HTTPS — HyperText Transfer Protocol

| Property | HTTP | HTTPS |
|----------|------|-------|
| Port | 80 | 443 |
| Encryption | None | TLS/SSL |
| Use | Web browsing | Secure web browsing |
| Status | Deprecated for sensitive data | Current standard |

**How HTTP works:**
1. Client sends an HTTP request (GET, POST, PUT, DELETE)
2. Server processes the request
3. Server returns an HTTP response with status code + body

```
GET /index.html HTTP/1.1
Host: www.example.com
User-Agent: Mozilla/5.0

HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 1234

<html>...</html>
```

---

### FTP — File Transfer Protocol

| Property | Value |
|----------|-------|
| Control port | 21 |
| Data port | 20 (active) / ephemeral (passive) |
| Authentication | Username + password (plaintext) |
| Secure alternative | SFTP (over SSH) or FTPS (FTP over TLS) |

FTP uses **two separate connections**: one for control commands and one for data transfer. This design causes firewall complications, leading to the widespread adoption of SFTP.

---

### SMTP — Simple Mail Transfer Protocol

| Property | Value |
|----------|-------|
| Port | 25 (server-to-server), 587 (client submission), 465 (SMTPS) |
| Direction | Sending only (not receiving) |
| Receiving protocols | IMAP (port 143/993), POP3 (port 110/995) |

**Email flow:**
```
Sender → SMTP → Sender's Mail Server → SMTP → Recipient's Mail Server → IMAP/POP3 → Recipient
```

---

### SSH — Secure Shell

| Property | Value |
|----------|-------|
| Port | 22 |
| Encryption | Asymmetric (key exchange) + symmetric (session) |
| Replaces | Telnet (port 23 — plaintext) |
| Uses | Remote login, tunnelling, SFTP, port forwarding |

SSH replaced Telnet because Telnet transmits everything — including passwords — in plaintext. SSH encrypts the entire session.

---

### DHCP — Dynamic Host Configuration Protocol

| Property | Value |
|----------|-------|
| Client port | 68 |
| Server port | 67 |
| Transport | UDP (broadcast) |
| Purpose | Automatically assigns IP, subnet mask, gateway, DNS server |

**DORA process:**
```
Client → DISCOVER (broadcast)
Server → OFFER (proposed IP)
Client → REQUEST (accept the offer)
Server → ACK (confirmed assignment)
```

---

### DNS — Domain Name System

DNS is covered in full detail in the other documentation files. At the Application Layer, DNS:
- Uses UDP port 53 for most queries
- Uses TCP port 53 for zone transfers and large responses
- Translates human-readable names to machine-readable IP addresses
- Is the backbone of virtually every internet transaction

---

## Protocol Comparison Table

| Protocol | Port(s) | Transport | Encrypted? | Purpose |
|----------|---------|-----------|-----------|---------|
| HTTP | 80 | TCP | ❌ | Web browsing |
| HTTPS | 443 | TCP | ✅ (TLS) | Secure web browsing |
| FTP | 20, 21 | TCP | ❌ | File transfer |
| SFTP | 22 | TCP | ✅ (SSH) | Secure file transfer |
| SMTP | 25, 587 | TCP | ✅ (STARTTLS) | Send email |
| IMAP | 143, 993 | TCP | ✅ (TLS) | Receive/read email |
| POP3 | 110, 995 | TCP | ✅ (TLS) | Download email |
| DNS | 53 | UDP + TCP | ❌ (DoH/DoT optional) | Name resolution |
| SSH | 22 | TCP | ✅ | Remote login |
| DHCP | 67, 68 | UDP | ❌ | IP address assignment |
| Telnet | 23 | TCP | ❌ (deprecated) | Remote login |
| SNMP | 161, 162 | UDP | ⚠️ v3 only | Network management |

---

## How Protocols Stack Together

When you visit `https://www.google.com`:

```
Layer 7 (Application) : HTTPS request — "GET / HTTP/1.1 Host: www.google.com"
                         DNS query first — "What is the IP of www.google.com?"
Layer 6 (Presentation) : TLS encryption of the HTTP data
Layer 5 (Session)      : TLS session establishment and management
Layer 4 (Transport)    : TCP segments (port 443) — reliable delivery
Layer 3 (Network)      : IP packets — routing across the internet
Layer 2 (Data Link)    : Ethernet frames — hop-by-hop delivery
Layer 1 (Physical)     : Electrical signals / photons / radio waves
```

The DNS query happens first (to get the IP), then the HTTPS connection is established.
