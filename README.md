# hyperswitch-cdk

To install dependencies:

```bash
bun install
```

To run:

```bash
bun run index.ts
```

This project was created using `bun init` in bun v1.0.2. [Bun](https://bun.sh) is a fast all-in-one JavaScript runtime.

### Stuff to Do

- [ ] Networking
  - [x] VPC
  - [ ] Subnets
  - [ ] NAT
  - [ ] Route Table
  - [ ] IGW
- [ ] Load Balancers
- [ ] Auto Scaling Groups
- [ ] Launch Templates
- [ ] RDS
- [ ] ElastiCache
- [ ] S3
- [ ] EKS
- [ ] Service Endpoints

### Decisions

- [ ] How should we have the subnet distribution?
  1. Similar to how we currently have in production
  2. We should create a HLD with the primary architecture in mind. [diagram](https://www.figma.com/file/4Izk569Fqq5yf8vf5RwyGW/HyperSwitch---PCI-DSS-Architecture-Diagrams?type=design&node-id=387-61&mode=design)

### Subnet design

We can consist of 4 Subnets

1. Public Incoming - (consisting of 1 subnet per AZ)
2. DMZ - (consisting of 1 subnet per AZ) (non-public)
3. Application - (consisting of 1 subnet per AZ) (isolated)
4. Storage Layer - (consisting of 1 subnet per AZ) (isolated)
5. Outbound - (consisting of 1 subnet per AZ) (connected to igw)

#### Structure

- api-public (exist in 1)
- envoy (exist in 2)
- external jump (exists in 2)
- EKS exists in (3)
- Internal Jump (3)
- squid (4)
