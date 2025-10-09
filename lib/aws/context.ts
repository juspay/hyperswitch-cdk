import { Construct } from "constructs";

interface ProxyContext {
  app_proxy_enabled: boolean;
  envoy_ami: string;
  squid_ami: string;
}

interface VPNContext {
  vpn_ips: string[];
}

interface AppContext
  extends ProxyContext,
          VPNContext {}

class ContextValidationError extends Error {
  constructor(key: string, expectedType: string, receivedValue: unknown) {
    super(
      `Invalid type for Context variable \`${key}\`. Expected: \`${expectedType}\`, Got: \`${typeof receivedValue}\`, Received Value: \`${JSON.stringify(receivedValue)}\`.`
    );
    this.name = "ContextValidationError";
  }
}

class ContextManager {
  private node: Construct["node"];

  constructor(node: Construct["node"]) {
    this.node = node;
  }

  // refs - https://uibakery.io/regex-library/ip-address
  private isValidIPv4(ip: string): boolean {
    const ipv4Regex = /^(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    return ipv4Regex.test(ip);
  }

  private isValidIPv6(ip: string): boolean {
    const ipv6Regex = /^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$/;
    return ipv6Regex.test(ip);
  }

  private isValidIP(ip: string): boolean {
    return this.isValidIPv4(ip) || this.isValidIPv6(ip);
  }

  private isBooleanValue(value: unknown): value is boolean | "true" | "false" {
    return (
      typeof value === "boolean"
        || (typeof value === "string" && ["true", "false"].includes(value.toLowerCase()))
    );
  }

  private isString(value: unknown): value is string {
    return typeof value === "string";
  }

  private isStringArray(value: unknown): value is string[] {
    return Array.isArray(value)
      && value.every((item) => this.isString(item));
  }

  getProxyConfig(): ProxyContext {
    const appProxyEnabledRaw = this.node.tryGetContext("app_proxy_enabled");
    const envoyAmiId = this.node.tryGetContext("envoy_ami");
    const squidAmiId = this.node.tryGetContext("squid_ami");
    if (appProxyEnabledRaw !== undefined && !this.isBooleanValue(appProxyEnabledRaw)) {
      throw new ContextValidationError(
        "app_proxy_enabled",
        "boolean or 'true'/'false'",
        appProxyEnabledRaw,
      );
    }
    const appProxyEnabled =
      typeof appProxyEnabledRaw === "boolean"
        ? appProxyEnabledRaw
        : (appProxyEnabledRaw as string)?.toLowerCase() === "true";
    if (envoyAmiId !== undefined && !this.isString(envoyAmiId)) {
      throw new ContextValidationError(
        "envoy_ami",
        "string",
        envoyAmiId,
      );
    }
    if (squidAmiId !== undefined && !this.isString(squidAmiId)) {
      throw new ContextValidationError(
        "squid_ami",
        "string",
        squidAmiId,
      );
    }
    return {
      app_proxy_enabled: appProxyEnabled,
      envoy_ami: envoyAmiId || "",
      squid_ami: squidAmiId || "",
    };
  }

  getVpnIps(): VPNContext {
    let vpnIpsRaw = this.node.tryGetContext("vpn_ips") || [];
    if (this.isString(vpnIpsRaw)) {
      vpnIpsRaw = vpnIpsRaw.split(",").map((ip) => ip.trim());
    }
    if (!this.isStringArray(vpnIpsRaw)) {
      throw new ContextValidationError(
        "vpn_ips",
        "string or string[]",
        vpnIpsRaw,
      );
    }
    if (vpnIpsRaw.length === 0) {
      console.warn("WARN: vpn_ips is empty.");
    }
    const cidrVpnIps = vpnIpsRaw.map((ip: string) => {
      if (!this.isValidIP(ip)) {
        throw new ContextValidationError(
          "vpn_ips",
          "valid IP address",
          ip,
        );
      }
      if (ip === "0.0.0.0") {
        return `${ip}/0`;
      }
      return `${ip}/32`;
    });
    return {
      vpn_ips: cidrVpnIps,
    };
  }

  getAllContext(): AppContext {
    return {
      ...this.getProxyConfig(),
      ...this.getVpnIps(),
    };
  }
}

export {
  ProxyContext,
  VPNContext,
  AppContext,
  ContextValidationError,
  ContextManager,
};
