import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
// fs and path might not be needed if locustFileContent is hardcoded or passed directly
// import * as fs from 'fs';
// import * as path from 'path';

export class LocustEks {
  namespace? : string;
  subnet? : string;
  nodeGroup? : {[labelName : string] : string};
  cluster : eks.Cluster;
  scope : Construct;

  constructor(cluster : eks.Cluster, scope : Construct, subnet: string, namespace: string, nodeTypeLabel : string, nodeGroupRole: cdk.aws_iam.Role) {
    this.cluster = cluster;
    this.scope = scope;
    this.subnet = subnet;
    
    // create locust namespace
    this.create_namepace(namespace);

    // Create ConfigMap
    const locustFileContent = ''; //add locust file
    const configMapData = {
      'API_KEY': ''
    };
    const locustConfigMapBaseName = `locust-scripts-cm`;
    const locustFileName = 'locustfile.py';
    const configMapConstruct = this.create_locust_configmap(locustConfigMapBaseName, locustFileName, locustFileContent, configMapData);

    //create nodegroup
    this.create_node_group(nodeTypeLabel, nodeGroupRole);

    // add helmchart
    const helmChartConstruct = this.add_helm_chart(
      'locust-hyperswitch', // releaseName
      'locust',             // chartName (standard locust chart)
      'https://locustio.github.io/helm-charts', // chartRepository
      '0.30.0', // chartVersion (use a specific, tested version)
      locustConfigMapBaseName,  // Use the base name, Helm chart will look for this name
      locustFileName,       // The key for the locustfile in the ConfigMap (e.g., 'locustfile.py')
      'API_KEY'             // The key for the API_KEY in the ConfigMap
    );

    // Ensure Helm chart depends on the ConfigMap
    if (helmChartConstruct && configMapConstruct) {
      helmChartConstruct.node.addDependency(configMapConstruct);
    }
  }

  create_locust_configmap(configMapName: string, locustFileName : string, locustFileContent : string, configMapData : {[key:string] : string}): eks.KubernetesManifest {
    const manifestData: { [key: string]: string } = {
      [locustFileName]: locustFileContent,
      ...configMapData,
    };

    const configMapManifestJson = {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        name: configMapName, // This name must be used by Helm chart values
        namespace: this.namespace,
      },
      data: manifestData,
    };

    return this.cluster.addManifest(`${configMapName}-manifest`, configMapManifestJson);
  }
  
  create_namepace(namespace : string){
    this.namespace = namespace;
    this.cluster.addManifest("locust-namespace", {
      apiVersion: "v1",
      kind: "Namespace",
      metadata: {
        name: this.namespace,
      },
    });
  }

  create_node_group(nodeTypeLabel: string, nodeGroupRole : cdk.aws_iam.Role) {
    this.nodeGroup = {'node-type' : 'locust'}
    const _locustNodegroup = this.cluster.addNodegroupCapacity("HSLocustNodegroup", {
      nodegroupName: "locust-ng",
      instanceTypes: [
        new ec2.InstanceType("c5.large"),
      ],
      minSize: 1,
      maxSize: 5,
      desiredSize: 1,
      labels: {
        "node-type": nodeTypeLabel,
      },
      subnets: { subnetGroupName: this.subnet || "locust-zone" },
      nodeRole: nodeGroupRole,
    });
  }

  add_helm_chart(
    releaseName: string,
    chartName: string,
    chartRepository: string,
    chartVersion: string,
    locustFileCmName: string,      // Name of the ConfigMap holding the locustfile and API_KEY
    locustFileNameInCm: string,  // Key for the locustfile in the ConfigMap data
    apiKeyCmKey: string          // Key for the API_KEY in the ConfigMap data
  ): eks.HelmChart | undefined { // Return type changed
    const envVarFromConfigMap = [
      {
        name: apiKeyCmKey, 
        valueFrom: {
          configMapKeyRef: {
            name: locustFileCmName, 
            key: apiKeyCmKey,       
          },
        },
      },
    ];

    const helmValues: { [key: string]: any } = {
      loadtest: {
        name: releaseName,
        locust_locustfile_configmap: locustFileCmName,
        locust_locustfile: locustFileNameInCm,
        locust_locustfile_path: "/mnt/locust",
      },
      master: {
        nodeSelector: { 'node-type': this.nodeGroup || 'locust' },
        environment: envVarFromConfigMap,
      },
      worker: {
        nodeSelector: { 'node-type': this.nodeGroup || 'locust' },
        environment: envVarFromConfigMap,
        hpa: { 
          enabled: true,
          minReplicas: 1,
          maxReplicas: 100,
          targetCPUUtilizationPercentage: 60
        }
      },
    };

    return this.cluster.addHelmChart(`${releaseName}-helm-chart`, {
      chart: chartName,
      repository: chartRepository,
      release: releaseName,
      namespace: this.namespace,
      version: chartVersion,
      values: helmValues,
        createNamespace: false,
    });
  }
}
