# Average CPU Usage SLO

In this tutorial, we will create a simple average CPU usage SLO that reads raw metrics.


## 1. Generate an SLO Mapping

1. Open a terminal in your Polaris workspace directory and create an SLO mapping type for the cost efficiency SLO.
An SLO mapping needs to be contained within a publishable Node.JS library project (i.e., an Nx project that builds a publishable npm package).
The name of the project is specified with the `--project` parameter.
If you don't have any library project in the workspace yet (as is the case in this demo), Polaris CLI can create one.
To this end, add the `--createLibProject=true` parameter and specify the import path that people using the library will use for importing it using the `--importPath` parameter.

    ```sh
    # Generate the cost efficiency SLO mapping type in the library project myslos, which is publishable as @my-org/my-slos
    # This generates the project libs/myslos
    polaris-cli g slo-mapping-type average-cpu-usage --project=myslos --createLibProject=true --importPath=@my-org/my-slos
    ```


1. Launch your favorite IDE or editor and open the file [`libs/myslos/src/lib/slo-mappings/average-cpu-usage.slo-mapping.prm.ts`](./libs/myslos/src/lib/slo-mappings/average-cpu-usage.slo-mapping.prm.ts) (`.prm` stands for Polaris Resource Model), which contains three types:
    * `AverageCpuUsageSloConfig` models the configuration options of the SLO. Add the following properties here:
        ```TypeScript
        /**
         * That target average CPU usage (in percent of the limit,
         * expressed as an integer).
         *
         * @minimum 0
         * @maximum 100
         */
        averageCpuTarget: number;

        /**
         * Specifies the tolerance within which no scaling will be performed
         *
         * @minimum 0
         * @default 10
         */
        tolerance?: number;
        ```
    * `AverageCpuUsageSloMappingSpec` is the type that brings together the SLO's configuration type, its output data type (`SloOutput`), and the type of workload targets it supports (`SloTarget`).
    Depending on your use case, you may want to change the output data type of the workload target type -- for the demo, we will leave them as they are.
    * `AverageCpuUsageSloMapping` is the API object that can be transformed, serialized, and sent to the orchestrator. Here, the `objectKind.group` value that is set in the constructor needs to be changed to match that of your organization. In this demo, we leave it at the generated value of `'slo.polaris-slo-cloud.github.io'`.
        ```TypeScript
        constructor(initData?: SloMappingInitData<AverageCpuUsageSloMapping>) {
          super(initData);
          this.objectKind = new ObjectKind({
            group: "slo.polaris-slo-cloud.github.io",
            version: "v1",
            kind: "AverageCpuUsageSloMapping",
          });
          initSelf(this, initData);
        }
        ```


1. The file [`libs/myslos/src/lib/init-polaris-lib.ts`](./libs/myslos/src/lib/init-polaris-lib.ts) contains the initialization function for your library, `initPolarisLib(polarisRuntime: PolarisRuntime)`, which has to register the object kind of our SLO mapping type and associate it with the SLO mapping type class in [transformation service](https://polaris-slo-cloud.github.io/polaris-slo-framework/typedoc/interfaces/core_src.PolarisTransformationService.html) of the Polaris runtime.
Since we generated a new library project, this step has already been done by the Polaris CLI.
If we had added the SLO mapping type to an existing project, we would need to perform this registration manually (this will be handled automatically by the Polaris CLI in the future):

    ```TypeScript
    export function initPolarisLib(polarisRuntime: PolarisRuntime): void {
      ...
      polarisRuntime.transformer.registerObjectKind(new AverageCpuUsageSloMapping().objectKind, AverageCpuUsageSloMapping);
    }
    ```


1. Next we need to generate the Kubernetes Custom Resource Definition (CRD) for our SLO mapping type and register it with Kubernetes.
We can do this executing the following command:

    ```sh
    # Generate the CRDs of the project `myslos` in the folder `libs/my-slos/crds`.
    polaris-cli gen-crds myslos

    # Register the CRD
    kubectl apply -f ./libs/myslos/crds
    ```


## 2. Generate the SLO Controller

1. To generate an SLO controller, we need to tell the Polaris CLI which SLO mapping type is going to be handled by the controller.
This is done using the `--sloMappingTypePkg` and the `--sloMappingType` arguments.
If the SLO mapping type package is configured as a [lookup path](https://www.typescriptlang.org/tsconfig#paths) in the workspace's `tsconfig.base.json`, Polaris CLI knows that the SLO mapping type is available locally, otherwise, it installs the respective npm package.
Polaris CLI automatically adds and configures the `@polaris-sloc/kubernetes` and `@polaris-sloc/prometheus` packages to enable the controller for use in Kubernetes and to read metrics from Prometheus.

    ```sh
    # Generate an SLO controller project for the AverageCpuUsageSloMapping in apps/average-cpu-usage-slo-controller
    polaris-cli g slo-controller average-cpu-usage-slo-controller --sloMappingTypePkg=@my-org/my-slos --sloMappingType=AverageCpuUsageSloMapping
    ```


1. The generated SLO controller project includes the following:
    * [`src/main.ts`](./apps/average-cpu-usage-slo-controller/src/main.ts) bootstraps the controller application by initializing the Polaris runtime with the Kubernetes library, configuring the Prometheus library as a metrics query backend, initializing the `@my-org/my-slos` library, registering the average CPU usage SLO mapping with the control loop and the watch manager, and starting the control loop.
    * [`src/app/slo/average-cpu-usage.controller.ts`](./apps/average-cpu-usage-slo-controller/src/app/slo/average-cpu-usage.controller.ts) contains the `AverageCpuUsageSlo` class that will act as the microcontroller for evaluating our SLO.
    * [`Dockerfile`](./apps/average-cpu-usage-slo-controller/Dockerfile) for building a container image of the controller
    * [`manifests/kubernetes`](./apps/average-cpu-usage-slo-controller/manifests) contains configuration YAML files for setting up and deploying the controller on Kubernetes.


1. Next, we implement the `AverageCpuUsageSlo` in [`apps/average-cpu-usage-slo-controller/src/app/slo/average-cpu-usage.controller.ts`](./apps/average-cpu-usage-slo-controller/src/app/slo/average-cpu-usage.controller.ts).
First we need to complete the `configure()` method.
This method is called by the Polaris SLO control loop after instantiating the class for a new or changed SLO Mapping.
It is used to store the configuration information in the class instance.
For this scenario, the generated code already stores all information needed, so you only need to return a resolved promise at the end of the method.
The `configure()` method requires returning a promise or an observable, because some SLO microcontrollers might need to perform more complex initialization.

    ```TypeScript
    configure(
      sloMapping: SloMapping<AverageCpuUsageSloConfig, SloCompliance>,
      metricsSource: MetricsSource,
      orchestrator: OrchestratorGateway
    ): ObservableOrPromise<void> {
      this.sloMapping = sloMapping;
      this.metricsSource = metricsSource;
      return Promise.resolve();
    }
    ```

1. Next, we need to implement the `evaluate()` method, which is called by the Polaris SLO control loop at a fixed interval to assess the current state of the SLO.
It has to determine "how much" the SLO is currently fulfilled.
To this end, it computes an `SloCompliance` value.
This is a percentage (expressed as an integer to conform to Kubernetes API conventions, e.g., `50` means 50%) that indicates how much the SLO is fulfilled.
If this value is `100`, the SLO is met exactly and no scaling action is required.
If this value is greater than `100`, the SLO is violated and scaling out/up is required. If this value is less than `100`, the system is performing better than the SLO demands and scaling in/down will be performed.
We implement the `evaluate()` method to return an `SloCompliance` that will be calculated by a private helper method:

    ```TypeScript
    evaluate(): ObservableOrPromise<SloOutput<SloCompliance>> {
      return this.calculateSloCompliance().then(compliance => ({
        sloMapping: this.sloMapping,
        
        // These parameters are passed to the elasticity strategy
        elasticityStrategyParams: {
          currSloCompliancePercentage: compliance,
          tolerance: this.sloMapping.spec.sloConfig.tolerance,
        },
      }));
    }

    private async calculateSloCompliance(): Promise<number> {
      // ToDo
    }
    ```

1. To calculate the `SloCompliance`, we need to construct a Prometheus query that will calculate the average CPU usage, as a percentage of the CPU limit available to each pod, over all pods of the target deployment.
To calculate the CPU usage of a pod with respect to its assigned CPU limit, we first need to sum the current CPU usage of all containers in a pod and then divide that by the sum of the CPU limits of all containers in the pod.
The following PromQL query calculates the average CPU usage in millicores across all pods of the deployment and divides it by the CPU limit of a pod in the deployment:

    ```sh
    # Average CPU usage (in millicores) over all pods in the deployment.
    avg (
      # Sum of the CPU usage of all containers in a pod.
      sum(
        # CPU Usage of a single container in a pod.
        rate(
        container_cpu_usage_seconds_total{
            namespace="default", pod=~"resource-consumer-.*", container!=""
          }[40s]
        )
      ) by (pod)
    )
    /
    # Sum of the CPU limits (in millicores) across all containers
    # that make up a pod of the deployment.
    sum (
      # Average CPU limit of a container across all pods 
      # (i.e., a trick to reduce the vector to a single dimension,
      # because all pods of the deployment have the same limits).
      avg(
        # CPU limit of a single container in a pod.
        kube_pod_container_resource_limits{
          resource="cpu", namespace="default", pod=~"resource-consumer-.*",  container_name!="kube-state-metrics"
        }
      ) by (container)
    )
    ```

1. We translate the above query into a DB independent Polaris raw metrics query (all unknown types can be imported from `@polaris-sloc/core`):

    ```TypeScript
    private async calculateSloCompliance(): Promise<number> {
      const sloTarget = this.sloMapping.spec.targetRef;

      // Average CPU usage (in millicores) over all pods in the deployment.
      const avgMilliCoresQ = this.metricsSource.getTimeSeriesSource()
        .select<number>(
          'container',
          'cpu_usage_seconds_total',
          TimeRange.fromDuration(Duration.fromSeconds(40)),
        )
        .filterOnLabel(
          LabelFilters.equal(
            'namespace',
            this.sloMapping.metadata.namespace,
          ),
        )
        .filterOnLabel(LabelFilters.regex('pod', `${sloTarget.name}-.*`))
        .filterOnLabel(LabelFilters.notEqual('container', ''))
        .rate()
        .sumByGroup(LabelGrouping.by('pod'))
        .averageByGroup();

      // CPU limit (in millicores) of a pod in the deployment.
      const limitMilliCoresQ = this.metricsSource.getTimeSeriesSource()
        .select('kube', 'pod_container_resource_limits')
        .filterOnLabel(LabelFilters.equal('resource', 'cpu'))
        .filterOnLabel(
          LabelFilters.equal(
            'namespace',
            this.sloMapping.metadata.namespace,
          ),
        )
        .filterOnLabel(LabelFilters.regex('pod', `${sloTarget.name}-.*`))
        .filterOnLabel(
          LabelFilters.notEqual(
            'container_name',
            'kube-state-metrics'
          ),
        )
        .averageByGroup(LabelGrouping.by('container'))
        .sumByGroup();

      // Average CPU usage in percent of the limit.
      const cpuUsageQ = avgMilliCoresQ.divideBy(limitMilliCoresQ);

      const result = await cpuUsageQ.execute();
      if (result.results.length === 0) {
        throw new Error('Metric could not be read.');
      }
      // The result is in a range from 0.0 to 1.0,
      // so we need to multiply by 100,
      // because our SLO is configured in a range from 0 to 100.
      const cpuAvg = result.results[0].samples[0].value * 100;
      if (!cpuAvg) {
        return 100;
      }
      const compliance = 
        cpuAvg / this.sloMapping.spec.sloConfig.averageCpuTarget;
      // A value of 1.0 of the `compliance` variable is equal to 100%,
      // but currSloCompliancePercentage expects an integer 
      // with a value of 100 indicating 100%.
      return Math.ceil(compliance * 100);
    }
    ```


## 3. Build and Deploy the SLO Controller

1. Since Polaris CLI has generated a Dockerfile for us, we can easily build the container image for our SLO controller.
For this tutorial, we will load the image directly into minikube.
Alternatively, we could adjust the tag of the image and push it to Dockerhub.
The tags for the image can be adjusted in the build command in [`apps/average-cpu-usage-slo-controller/project.json`](./apps/average-cpu-usage-slo-controller/project.json) `targets.docker-build.options.commands` (the user friendliness of this step will be improved in the future).
When changing the tag here, we also need to change the image name in [`apps/average-cpu-usage-slo-controller/manifests/kubernetes/2-slo-controller.yaml`](./apps/average-cpu-usage-slo-controller/manifests/kubernetes/2-slo-controller.yaml)

    ```JSON
    "commands": [
        "docker build ... -t polarissloc/average-cpu-usage-slo-controller:latest ."
    ],
    ```

    ```sh
    # Build SLO controller container image
    polaris-cli docker-build average-cpu-usage-slo-controller

    # Load the container image into your minikube cluster
    minikube image load polarissloc/average-cpu-usage-slo-controller:latest
    ```


1. If our Prometheus instance is not reachable under the DNS name `prometheus-kube-prometheus-prometheus.monitoring.svc` or on port `9090` (defaults for our [testbed setup](https://github.com/polaris-slo-cloud/polaris-slo-framework/tree/master/testbeds/kubernetes)), we need to change the `PROMETHEUS_HOST` and/or `PROMETHEUS_PORT` environment variables in [`apps/average-cpu-usage-slo-controller/manifests/kubernetes/2-slo-controller.yaml`](./apps/average-cpu-usage-slo-controller/manifests/kubernetes/2-slo-controller.yaml).

    ```YAML
    env:
      # The hostname and port of the Prometheus service (adapt if necessary):
      - name: PROMETHEUS_HOST
        value: prometheus-kube-prometheus-prometheus.monitoring.svc
      - name: PROMETHEUS_PORT
        value: '9090'
    ```

1. Deploy the SLO controller using Polaris CLI.

    ```sh
    # Deploy the controller
    polaris-cli deploy average-cpu-usage-slo-controller

    # Verify that the deployment worked
    kubectl get deployments.apps -n polaris
    ```

    Alternatively, you can run and debug the controller locally as well.
    To this end, please follow the debugging instructions [here](https://github.com/polaris-slo-cloud/polaris-slo-framework/tree/master/ts#debugging-in-vs-code).



## 4. Generate and Apply an SLO Mapping Instance

1. To configure and apply the average CPU usage SLO, we need to generate an instance of the `CostEfficiencySloMapping` and configure and apply it.

    ```sh
    # Generate a AverageCpuUsageSloMapping instance in `slo-mappings/demo-mapping.ts`
    polaris-cli g slo-mapping demo-mapping --sloMappingTypePkg=@my-org/my-slos --sloMappingType=AverageCpuUsageSloMapping
    ```


1. Open the generated file [`slo-mappings/demo-mapping.ts`](./slo-mappings/demo-mapping.ts) and configure it for the resource-consumer deployment.

    ```TypeScript
    export default new AverageCpuUsageSloMapping({
      metadata: new ApiObjectMetadata({
        // The namespace must be the same as the SloTarget
        namespace: 'default',
        name: 'avg-cpu-test',
      }),
      spec: new AverageCpuUsageSloMappingSpec({
        // Identifies the workload to which to apply the SLO.
        targetRef: new SloTarget({
          group: 'apps',
          version: 'v1',
          kind: 'Deployment',
          name: 'resource-consumer',
        }),
        // We want to do horizontal scaling.
        elasticityStrategy: new HorizontalElasticityStrategyKind(),
        sloConfig: {
          // We aim for 70% average CPU usage.
          averageCpuTarget: 70,
          tolerance: 5,
        },
      }),
    });
    ```


1. Apply the SLO mapping:

    ```sh
    # See what the serialized SLO mapping instance looks like
    polaris-cli serialize demo-mapping

    # Apply the SLO mapping to your cluster
    polaris-cli serialize demo-mapping | tail -n +3 | kubectl apply -f -

    # Watch the logs of the SLO controller to see what is happening
    kubectl logs -f -n polaris <name of the average-cpu-usage-slo-controller pod>
    ```

1. To force some scaling, we need to instruct the resource-consumer to consume some CPU.
To this end, we need to be able to reach it with curl.
So, we temporarily forward a port to it using kubectl (in a second terminal):

    ```sh
    # Forward local port 8080 to port 8080 of the deployed resource-consumer service
    kubectl port-forward service/resource-consumer 8080:8080
    ```

1. To force some scaling, we can instruct the `resource-consumer` to consume `90%` of its CPU resources:

    ```sh
    # Consume 900 millicores for 180 seconds:
    curl --data "millicores=900&durationSec=180" http://localhost:8080/ConsumeCPU

    # After the SLO controller reacts, check if the number of replicas has increased:
    kubectl get deployment resource-consumer

    # Note: when multiple replicas of resource-consumer are active, 
    # each curl request to the service will be distributed to the 
    # replicas in a Round-robin fashion.
    ```
