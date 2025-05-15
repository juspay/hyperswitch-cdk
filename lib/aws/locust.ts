import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as fs from 'fs';
import * as path from 'path';

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

    // create configmap

    //create nodegroup
    this.create_node_group(nodeTypeLabel, nodeGroupRole);

    // add helmchart

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

}

// export interface LocustStackProps extends cdk.StackProps {
//   readonly vpc: ec2.IVpc;
//   readonly cluster: eks.ICluster;
//   readonly locustFilePath?: string; // Path to your local locustfile (e.g., './my-tests/locustfile.py')
//   readonly locustTestFileName?: string; // The name of the file inside the ConfigMap (e.g., 'main.py')
//   readonly customLocustEnvVars?: { [key: string]: string }; //  e.g., { TARGET_URL: 'http://example.com' }
//   readonly helmChartRepository?: string; // Helm chart repository URL
//   readonly helmChartName?: string; // Name of the chart in the repository
//   readonly helmChartVersion?: string; // Version of the Locust Helm chart
//   readonly releaseName?: string; // Helm release name
//   readonly namespace?: string; // Kubernetes namespace for deployment
//   readonly baseHelmValues?: { [key: string]: any }; // Base values to merge with
// }

// export class LocustStack extends cdk.Stack {
//   constructor(scope: Construct, id: string, props: LocustStackProps) {
//     super(scope, id, props);

//     const {
//       cluster,
//       locustFilePath,
//       locustTestFileName = 'main.py', // Default test file name
//       customLocustEnvVars = {},
//       helmChartRepository = 'https://locustio.github.io/helm-charts',
//       helmChartName = 'locust',
//       helmChartVersion = '0.30.0', // Using a recent stable version
//       releaseName = 'locust-loadtest',
//       namespace = 'locust', // Default namespace for Locust
//       baseHelmValues = {},
//     } = props;

//     let locustfileConfigMapName: string | undefined;
//     let finalLocustTestFileName = locustTestFileName;

//     if (locustFilePath) {
//       if (!fs.existsSync(locustFilePath)) {
//         throw new Error(`Locustfile not found at path: ${locustFilePath}`);
//       }
//       const locustfileContent = fs.readFileSync(locustFilePath, 'utf-8');
//       locustfileConfigMapName = `${releaseName}-locustfile-cm`;
//       finalLocustTestFileName = path.basename(locustFilePath); // Use the actual filename from the path

//       const configMapManifest = {
//         apiVersion: 'v1',
//         kind: 'ConfigMap',
//         metadata: {
//           name: locustfileConfigMapName,
//           namespace: namespace, // Ensure ConfigMap is in the same namespace as Helm release
//         },
//         data: {
//           [finalLocustTestFileName]: locustfileContent,
//         },
//       };

//       // Add the ConfigMap manifest to the cluster
//       // Note: The EKS cluster needs to have a default namespace or the namespace must be created
//       // if it doesn't exist prior to adding namespaced resources.
//       // For simplicity, we assume the namespace will be created by the Helm chart or exists.
//       new eks.KubernetesManifest(this, `${id}-LocustfileConfigMap`, {
//         cluster: cluster,
//         manifest: [configMapManifest],
//         overwrite: true, // Allows updates to the ConfigMap if the locustfile changes
//       });
//     }

//     const helmValues: { [key: string]: any } = {
//       ...baseHelmValues,
//       loadtest: {
//         ...(baseHelmValues.loadtest || {}),
//         environment: {
//           ...(baseHelmValues.loadtest?.environment || {}),
//           ...customLocustEnvVars,
//         },
//       },
//       // Ensure master and worker sections exist if not in baseHelmValues
//       master: {
//         ...(baseHelmValues.master || {}),
//       },
//       worker: {
//         ...(baseHelmValues.worker || {}),
//       },
//     };

//     if (locustfileConfigMapName) {
//       helmValues.loadtest.locust_locustfile_configmap = locustfileConfigMapName;
//       helmValues.loadtest.locust_locustfile = finalLocustTestFileName;
//       // As per helm/locust.yaml, path is usually /mnt/locust
//       helmValues.loadtest.locust_locustfile_path = baseHelmValues.loadtest?.locust_locustfile_path || "/mnt/locust";
//     }


//     // Deploy Locust using the Helm chart
//     cluster.addHelmChart(`${id}-LocustHelmChart`, {
//       chart: helmChartName,
//       repository: helmChartRepository,
//       release: releaseName,
//       namespace: namespace,
//       version: helmChartVersion,
//       values: helmValues,
//       createNamespace: true, // Create the namespace if it doesn't exist
//     });
//   }
// }
