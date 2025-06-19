import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";

/**
 * Properties for the SecurityGroups construct
 */
export interface SecurityGroupsProps {
  /**
   * The VPC where security groups will be created
   */
  vpc: ec2.IVpc;
  
  /**
   * Whether to create standalone mode security groups
   * @default false
   */
  isStandalone?: boolean;
  
  /**
   * Whether app proxy is enabled (for creating proxy-specific security groups)
   * @default false
   */
  appProxyEnabled?: boolean;
}

/**
 * Centralized security groups management for Hyperswitch infrastructure.
 * This construct creates all security groups upfront and improve maintainability.
 */
export class SecurityGroups extends Construct {
  // Core security groups
  public readonly lbSecurityGroup: ec2.SecurityGroup;
  public readonly istioInternalLbSecurityGroup: ec2.SecurityGroup;
  public readonly envoyAsgSecurityGroup: ec2.SecurityGroup;
  public readonly vpcEndpointSecurityGroup: ec2.SecurityGroup;
  public readonly grafanaIngressLbSecurityGroup: ec2.SecurityGroup;
  public readonly clusterSecurityGroup: ec2.SecurityGroup;
  public readonly envoyExternalLbSecurityGroup?: ec2.SecurityGroup;
  public readonly squidInternalLbSecurityGroup?: ec2.SecurityGroup;
  public readonly squidAsgSecurityGroup?: ec2.SecurityGroup;
  
  // Standalone mode security groups
  public readonly ec2SecurityGroup?: ec2.SecurityGroup;
  public readonly appAlbSecurityGroup?: ec2.SecurityGroup;
  public readonly sdkAlbSecurityGroup?: ec2.SecurityGroup;
  
  constructor(scope: Construct, id: string, props: SecurityGroupsProps) {
    super(scope, id);
    
    const { vpc, isStandalone = false, appProxyEnabled = false } = props;
    
    // Create core security groups that are always needed
    
    // 1. Load Balancer Security Group
    this.lbSecurityGroup = new ec2.SecurityGroup(this, 'LoadBalancerSG', {
      vpc: vpc,
      allowAllOutbound: false,
      securityGroupName: 'hs-loadbalancer-sg',
      description: 'Security group for load balancers',
    });
    
    this.lbSecurityGroup.addIngressRule(
      ec2.Peer.anyIpv4(), 
      ec2.Port.allTraffic(),
      'Allow all inbound traffic'
    );
    
    // 2. Istio Internal Load Balancer Security Group
    this.istioInternalLbSecurityGroup = new ec2.SecurityGroup(this, 'IstioInternalLbSG', {
      vpc: vpc,
      allowAllOutbound: false,
      description: 'Security group for Istio internal ALB - Bridge between Envoy ASG and EKS',
    });
    
    // 3. Envoy ASG Security Group
    this.envoyAsgSecurityGroup = new ec2.SecurityGroup(this, 'EnvoyAsgSG', {
      vpc: vpc,
      allowAllOutbound: false,
      description: 'Security group for Envoy ASG EC2 instances',
    });
    
    // 4. VPC Endpoint Security Group
    this.vpcEndpointSecurityGroup = new ec2.SecurityGroup(this, 'VpcEndpointSG', {
      vpc: vpc,
      allowAllOutbound: false,
      description: 'Security group for VPC interface endpoints',
    });
    
    // 5. Grafana Ingress Load Balancer Security Group
    this.grafanaIngressLbSecurityGroup = new ec2.SecurityGroup(this, 'GrafanaIngressLbSG', {
      vpc: vpc,
      allowAllOutbound: true,
      securityGroupName: 'grafana-ingress-lb',
      description: 'Security group for Grafana ingress load balancer',
    });
    
    // 6. EKS Cluster Security Group
    this.clusterSecurityGroup = new ec2.SecurityGroup(this, 'ClusterSecurityGroup', {
      vpc: vpc,
      allowAllOutbound: true,
      description: 'Security group for EKS cluster',
    });
    
    // Create app proxy security groups if enabled
    if (appProxyEnabled) {
      // Envoy External Load Balancer Security Group
      this.envoyExternalLbSecurityGroup = new ec2.SecurityGroup(this, 'EnvoyExternalLbSecurityGroup', {
        vpc: vpc,
        description: 'Security group for Envoy external ALB',
        allowAllOutbound: false,
      });
      
      // Squid Internal Load Balancer Security Group
      this.squidInternalLbSecurityGroup = new ec2.SecurityGroup(this, 'SquidInternalLbSecurityGroup', {
        vpc: vpc,
        description: 'Security group for Squid internal ALB',
        allowAllOutbound: false,
      });
      
      // Squid ASG Security Group
      this.squidAsgSecurityGroup = new ec2.SecurityGroup(this, 'SquidAsgSecurityGroup', {
        vpc: vpc,
        description: 'Security group for Squid Auto Scaling Group instances',
        allowAllOutbound: false,
      });
    }
    
    // Create standalone mode security groups if needed
    if (isStandalone) {
      // EC2 Security Group for standalone instances
      this.ec2SecurityGroup = new ec2.SecurityGroup(this, 'EC2SecurityGroup', {
        vpc: vpc,
        description: 'Security group for EC2 instances',
        allowAllOutbound: true,
      });
      
      // App ALB Security Group
      this.appAlbSecurityGroup = new ec2.SecurityGroup(this, 'AppAlbSG', {
        vpc: vpc,
        description: 'SG for App ALB',
        allowAllOutbound: true,
      });
      
      // SDK ALB Security Group
      this.sdkAlbSecurityGroup = new ec2.SecurityGroup(this, 'SdkAlbSG', {
        vpc: vpc,
        description: 'SG for SDK ALB',
        allowAllOutbound: true,
      });
      
      // Add standalone mode specific rules
      this.setupStandaloneModeRules();
    }
    
    // Set up basic security group rules that don't depend on other constructs
    this.setupBasicRules();
    
    // Set up cross-security group rules
    this.setupCrossSecurityGroupRules();
    
    // Set up app proxy workflow rules if enabled
    if (appProxyEnabled) {
      this.setupAppProxyWorkflowRules();
    }
  }
  
  /**
   * Set up basic security group rules that don't depend on other constructs
   */
  private setupBasicRules(): void {
    // Envoy ASG instance rules
    if (!this.envoyExternalLbSecurityGroup) {
      this.envoyAsgSecurityGroup.addIngressRule(
        this.lbSecurityGroup,
        ec2.Port.tcp(80),
        'Allow HTTP traffic from External Envoy ALB (legacy)'
      );
    }
    
    // Egress: Allow HTTPS to S3 (via VPC Gateway Endpoint)
    this.envoyAsgSecurityGroup.addEgressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(443),
      'Allow HTTPS to S3 (via VPC Gateway Endpoint)'
    );
    
    // Egress: Allow DNS
    this.envoyAsgSecurityGroup.addEgressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.udp(53),
      'Allow DNS UDP'
    );
    this.envoyAsgSecurityGroup.addEgressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(53),
      'Allow DNS TCP'
    );
    
    // VPC Endpoint Security Group rules
    // Allow HTTPS traffic from load balancer security group
    this.vpcEndpointSecurityGroup.addIngressRule(
      this.lbSecurityGroup,
      ec2.Port.tcp(443),
      'Allow HTTPS from load balancer security group'
    );
  }
  
  /**
   * Set up cross-security group rules
   */
  private setupCrossSecurityGroupRules(): void {
    // Istio Internal LB rules
    // Allow traffic from Envoy ASG security group
    this.istioInternalLbSecurityGroup.addIngressRule(
      this.envoyAsgSecurityGroup,
      ec2.Port.tcp(80),
      'Allow HTTP from Envoy ASG instances only'
    );
    
    // Envoy ASG can send traffic to Istio Internal LB
    this.envoyAsgSecurityGroup.addEgressRule(
      this.istioInternalLbSecurityGroup,
      ec2.Port.tcp(80),
      'Allow HTTP to Istio Internal LB only'
    );
  }
  
  /**
   * Set up standalone mode specific rules
   */
  private setupStandaloneModeRules(): void {
    if (!this.appAlbSecurityGroup || !this.sdkAlbSecurityGroup || !this.ec2SecurityGroup) {
      return;
    }
    
    // App ALB rules
    this.appAlbSecurityGroup.addIngressRule(
      ec2.Peer.anyIpv4(), 
      ec2.Port.tcp(80),
      'Allow HTTP from anywhere'
    );
    this.appAlbSecurityGroup.addIngressRule(
      ec2.Peer.anyIpv4(), 
      ec2.Port.tcp(9000),
      'Allow port 9000 from anywhere'
    );
    
    // SDK ALB rules
    this.sdkAlbSecurityGroup.addIngressRule(
      ec2.Peer.anyIpv4(), 
      ec2.Port.tcp(9090),
      'Allow port 9090 from anywhere'
    );
    this.sdkAlbSecurityGroup.addIngressRule(
      ec2.Peer.anyIpv4(), 
      ec2.Port.tcp(5252),
      'Allow port 5252 from anywhere'
    );
    
    // EC2 instance rules
    this.ec2SecurityGroup.addEgressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(443),
      'Allow outbound HTTPS traffic for SSM'
    );
  }
  
  /**
   * Add rules for EKS cluster security group after cluster is created
   * @param clusterSecurityGroup The EKS cluster security group
   */
  public addEksClusterRules(clusterSecurityGroup: ec2.ISecurityGroup): void {
    // Add outbound rule from LB to EKS cluster
    this.lbSecurityGroup.addEgressRule(
      clusterSecurityGroup,
      ec2.Port.allTraffic(),
      'Allow all traffic to EKS cluster'
    );
    
    // Add outbound rule from Istio Internal LB to EKS cluster
    this.istioInternalLbSecurityGroup.addEgressRule(
      clusterSecurityGroup,
      ec2.Port.tcp(80),
      'Allow HTTP to EKS cluster only'
    );
  }
  
  /**
   * Add VPN-specific ingress rules to Grafana security group
   * @param vpnIps Array of VPN IP addresses
   */
  public addGrafanaVpnRules(vpnIps: string[]): void {
    vpnIps.forEach(ip => {
      if (ip !== "0.0.0.0/0") {
        const vpnPorts = [443, 80];
        vpnPorts.forEach(port =>
          this.grafanaIngressLbSecurityGroup.addIngressRule(
            ec2.Peer.ipv4(ip), 
            ec2.Port.tcp(port),
            `Allow port ${port} from VPN IP ${ip}`
          )
        );
      }
    });
  }
  
  /**
   * Add rules for VPC endpoints from private subnet CIDRs
   * @param privateSubnets Array of private subnets
   */
  public addVpcEndpointSubnetRules(privateSubnets: ec2.ISubnet[]): void {
    privateSubnets.forEach((subnet, index) => {
      this.vpcEndpointSecurityGroup.addIngressRule(
        ec2.Peer.ipv4(subnet.ipv4CidrBlock),
        ec2.Port.tcp(443),
        `Allow HTTPS from private subnet ${subnet.subnetId}`
      );
    });
  }
  
  /**
   * Set up app proxy workflow rules
   */
  private setupAppProxyWorkflowRules(): void {
    if (!this.envoyExternalLbSecurityGroup || !this.squidInternalLbSecurityGroup || !this.squidAsgSecurityGroup) {
      return;
    }
    
    // 1. CloudFront -> Envoy External LB (HTTPS/HTTP)
    this.envoyExternalLbSecurityGroup.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(80),
      'Allow HTTP from CloudFront'
    );
    this.envoyExternalLbSecurityGroup.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(443),
      'Allow HTTPS from CloudFront'
    );
    
    // 2. Envoy External LB -> Envoy ASG
    this.envoyExternalLbSecurityGroup.addEgressRule(
      this.envoyAsgSecurityGroup,
      ec2.Port.tcp(8080),
      'Allow traffic to Envoy ASG instances'
    );
    this.envoyAsgSecurityGroup.addIngressRule(
      this.envoyExternalLbSecurityGroup,
      ec2.Port.tcp(8080),
      'Allow traffic from Envoy External LB'
    );
    
    // 3. Envoy ASG -> Istio Internal LB (already configured in setupCrossSecurityGroupRules)
    
    // 4. Istio Internal LB -> EKS Cluster (handled in addEksClusterRules)
    
    // 5. EKS Cluster -> Squid Internal LB (for outbound traffic)
    this.clusterSecurityGroup.addEgressRule(
      this.squidInternalLbSecurityGroup,
      ec2.Port.tcp(3128),
      'Allow outbound traffic to Squid proxy'
    );
    this.squidInternalLbSecurityGroup.addIngressRule(
      this.clusterSecurityGroup,
      ec2.Port.tcp(3128),
      'Allow traffic from EKS cluster'
    );
    
    // 6. Squid Internal LB -> Squid ASG
    this.squidInternalLbSecurityGroup.addEgressRule(
      this.squidAsgSecurityGroup,
      ec2.Port.tcp(3128),
      'Allow traffic to Squid ASG instances'
    );
    this.squidAsgSecurityGroup.addIngressRule(
      this.squidInternalLbSecurityGroup,
      ec2.Port.tcp(3128),
      'Allow traffic from Squid Internal LB'
    );
    
    // 7. Squid ASG -> Internet (outbound traffic)
    this.squidAsgSecurityGroup.addEgressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(80),
      'Allow HTTP to internet'
    );
    this.squidAsgSecurityGroup.addEgressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(443),
      'Allow HTTPS to internet'
    );
    
    // Additional rules for health checks
    this.setupHealthCheckRules();
  }
  
  /**
   * Set up health check rules for ALBs
   */
  private setupHealthCheckRules(): void {
    if (!this.envoyExternalLbSecurityGroup || !this.squidInternalLbSecurityGroup || !this.squidAsgSecurityGroup) {
      return;
    }
    
    // Health check rules for Envoy ALB
    this.envoyExternalLbSecurityGroup.addEgressRule(
      this.envoyAsgSecurityGroup,
      ec2.Port.tcp(8081), // Health check port
      'Health check to Envoy instances'
    );
    this.envoyAsgSecurityGroup.addIngressRule(
      this.envoyExternalLbSecurityGroup,
      ec2.Port.tcp(8081),
      'Health check from Envoy LB'
    );
    
    // Health check rules for Squid ALB
    this.squidInternalLbSecurityGroup.addEgressRule(
      this.squidAsgSecurityGroup,
      ec2.Port.tcp(3129), // Health check port
      'Health check to Squid instances'
    );
    this.squidAsgSecurityGroup.addIngressRule(
      this.squidInternalLbSecurityGroup,
      ec2.Port.tcp(3129),
      'Health check from Squid LB'
    );
  }
}
