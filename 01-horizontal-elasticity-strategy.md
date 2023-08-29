# Custom Horizontal Elasticity Strategy

In this tutorial, we will create a custom controller for enforcing a horizontal elasticity strategy.

## 1. Create an Elasticity Strategy type

1. Open a terminal in your Polaris workspace directory and create an elasticity strategy type for the horizontal elasticity strategy.
An elasticity strategy type needs to be contained within a publishable Node.JS library project (i.e., an Nx project that builds a publishable npm package).
The name of the project is specified with the `--project` parameter.
If you don't have any library project in the workspace yet (as is the case in this demo), Polaris CLI can create one.
To this end, add the `--createLibProject=true` parameter and specify the import path that people using the library will use for importing it using the `--importPath` parameter.

    ```sh
    # Generate the MyHorizontalElasticityStrategy type in the library project mystrategies, which is publishable as @my-org/my-strategies
    # This generates the project libs/mystrategies
    polaris-cli g elasticity-strategy my-horizontal-elasticity-strategy --project=mystrategies --createLibProject=true --importPath=@my-org/my-strategies
    ```
    See the changes [here](https://github.com/polaris-slo-cloud/polaris-demos/commit/1715b8c5de5185561cf4812575aa4f9f12ae4c45).


1. Launch your favorite IDE or editor and open the file `libs/mystrategies/src/lib/elasticity/my-horizontal-elasticity-strategy.prm.ts` (`.prm` stands for Polaris Resource Model).
It contains a list of ToDos and three types:

    * `MyHorizontalElasticityStrategyConfig` models the configuration options of the elasticity strategy. Add the following properties here:

        ```TypeScript
        /**
         * The minimum number of replicas that the target workload must have.
         */
        minReplicas?: number;

        /**
         * The maximum number of replicas that the target workload must have.
         */
        maxReplicas?: number;
        ```

    * `MyHorizontalElasticityStrategyKind` can be used in an SLO mapping to reference this type of elasticity strategy.
    It also defines the input data type of the elasticity strategy (`SloCompliance`), which has to match the output data type of the SLO(s) that you want to use the elasticity strategy with, and the type of workload targets it supports (`SloTarget`).
    Depending on your use case, you may want to change the output data type of the workload target type -- for the demo, we will leave them as they are.
    Since this class defines the `ObjectKind` of the elasticity strategy, you need to adapt the `group` value that is set in the constructor to match that of your organization.
    In this demo, we leave it as it is, `'elasticity.polaris-slo-cloud.github.io'`.

        ```TypeScript
        constructor() {
            super({
                group: 'elasticity.polaris-slo-cloud.github.io',
                version: 'v1',
                kind: 'MyHorizontalElasticityStrategy',
            });
        }
        ```

    * `MyHorizontalElasticityStrategy` is the API object that can be transformed, serialized, and sent to the orchestrator.
    It takes three generic type parameters: i) the elasticity strategy's input data type, ii) the supported workload type, and iii) the data type that defines the strategy's configuration.
    The first two must match those of `MyHorizontalElasticityStrategyKind` and the third one refers to the `MyHorizontalElasticityStrategyConfig` interface that was generated.

    See the changes [here](https://github.com/polaris-slo-cloud/polaris-demos/commit/4cf5876b341942441c28e404e46613b24ede2b0b).


1. The file `libs/mystrategies/src/lib/init-polaris-lib.ts` contains the initialization function for your library, `initPolarisLib(polarisRuntime: PolarisRuntime)`, which has to register the object kind of our elasticity strategy and associate it with the elasticity strategy class in [transformation service](https://polaris-slo-cloud.github.io/polaris-slo-framework/typedoc/interfaces/core_src.PolarisTransformationService.html) of the Polaris runtime.
Since we generated a new library project, this step has already been done by the Polaris CLI.
If we had added the Elasticity Strategy type to an existing project, we would need to perform this registration manually (this will be handled automatically by the Polaris CLI in the future):

    ```TypeScript
    export function initPolarisLib(polarisRuntime: PolarisRuntime): void {
        ...
        polarisRuntime.transformer.registerObjectKind(new MyHorizontalElasticityStrategy().objectKind, MyHorizontalElasticityStrategy);
    }
    ```


1. Next we need to generate the Kubernetes Custom Resource Definition (CRD) for our elasticity strategy type, so that it can be registered with Kubernetes.
We can do this executing the following command:

    ```sh
    # Generate the CRDs of the project `mystrategies` in the folder `libs/mystrategies/crds`.
    polaris-cli gen-crds mystrategies
    ```
    See the changes [here](https://github.com/polaris-slo-cloud/polaris-demos/commit/5d7469f7a94f4162e671157625adb1f3af3a475b).



## 2. Create the Elasticity Strategy Controller

1. To generate an elasticity strategy controller, we need to tell the Polaris CLI which elasticity strategy type is going to be handled by the controller.
This is done using the `--eStratTypePkg` and the `--eStratType` arguments.
If the elasticity strategy type package is configured as a [lookup path](https://www.typescriptlang.org/tsconfig#paths) in the workspace's `tsconfig.base.json`, Polaris CLI knows that the elasticity strategy type is available locally, otherwise, it installs the respective npm package.
Polaris CLI automatically adds and configures the `@polaris-sloc/kubernetes` package to enable the controller for use in Kubernetes.

    ```sh
    # Generate an elasticity strategy controller project for the MyHorizontalElasticityStrategy in apps/my-horizontal-elasticity-strategy-controller
    polaris-cli g elasticity-strategy-controller my-horizontal-elasticity-strategy-controller --eStratTypePkg=@my-org/my-strategies --eStratType=MyHorizontalElasticityStrategy
    ```
    See the changes [here](https://github.com/polaris-slo-cloud/polaris-demos/commit/e8f2b9846e0d31750d690c78c2c1f05a0e7e1ed9).


1. The generated elasticity strategy controller project includes the following:

    * `src/main.ts` bootstraps the controller application by initializing the Polaris runtime with the Kubernetes library, initializing the `@my-org/my-strategies` library, registering the `MyHorizontalElasticityStrategyKind` with the elasticity strategy manager, linking it to the newly generated `MyHorizontalElasticityStrategyController`, and starting the watch on the horizontal elasticity strategies on the orchestrator.
    * `src/app/elasticity/my-horizontal-elasticity-strategy.controller.ts` contains the `MyHorizontalElasticityStrategyController` class that will act as the microcontroller for enacting the elasticity strategy.
    A single instance of this microcontroller class is created to handle all elasticity strategy instances.
    Note the difference to SLO controllers, where a distinct microcontroller instance is created for each SLO mapping instance.
    This is because each SLO mapping contains a distinct configuration and the SLO with that specific configuration needs to evaluated periodically.
    Instead an elasticity strategy is only executed when an elasticity strategy type instance is created or modified and that instance contains all the information needed to execute the strategy.
    * `Dockerfile` for building a container image of the controller
    * `manifests/kubernetes` contains configuration YAML files for setting up and deploying the controller on Kubernetes.


1. The file with the `MyHorizontalElasticityStrategyController` class contains a list of ToDos that need to be covered.

    * If the generic parameters of the elasticity strategy kind were changed from the defaults, they need to be adapted here as well - in this case, no changes are necessary.
    * If the elasticity strategy uses an input type other than `SloCompliance`, we need to change the controller's superclass to `ElasticityStrategyController` (more on this shortly).
    * The elasticity strategy's actions need to be implemented in the `execute()` method.
    * The `manifests/1-rbac.yaml` file needs to be adapted to grant permissions on the API group and kind of the elasticity strategy kind. If the default API group (`elasticity.polaris-slo-cloud.github.io`) and kind were not changed in the elasticity strategy type (we didn't change them in the demo), nothing needs to be done here.

    The generated code creates an `OrchestratorClient` for interaction with the orchestrator and a `StabilizationWindowTracker` that can be used to ensure that we don't execute an elasticity strategy twice for the same target in a short time window, where the effect of the last operation cannot be seen yet (i.e., the stabilization window).
    All framework classes and methods have JSDoc applied, so hovering over a method name will reveal its documentation or that of the method in the superclass or interface.

    An [elasticity strategy controller](https://polaris-slo-cloud.github.io/polaris-slo-framework/typedoc/interfaces/core_src.ElasticityStrategyController.html) must implement two main methods:

    * `checkIfActionNeeded()` checks if the specified elasticity strategy instance requires an execution of the strategy's actions.
    E.g., if the value of `SloCompliance` is within the toleration interval, no action is needed.
    When using `SloCompliance` as input (and thus the `SloComplianceElasticityStrategyControllerBase` superclass), this method does not need to be implemented, because it is handled by the superclass.
    * `execute()` performs the actions that constitute the elasticity strategy, e.g., adding or removing replicas.



1. If we wanted to implement a never before seen elasticity strategy, we would need to implement the `execute()` method manually.
However, since horizontal and vertical scaling are very common, Polaris provides superclasses for each of these two elasticity strategy types (see [here](https://github.com/polaris-slo-cloud/polaris-slo-framework/tree/master/ts/libs/core/src/lib/elasticity/public/control/impl/base)).
Thus, we can delete most of the boilerplate code and extend the `HorizontalElasticityStrategyControllerBase`, which requires us to only compute the new number of replicas:

    ```TypeScript
    protected computeScale(
        elasticityStrategy: ElasticityStrategy<SloCompliance, SloTarget, MyHorizontalElasticityStrategyConfig>,
        currScale: Scale,
    ): Promise<Scale> {
        const newScale = new Scale(currScale);
        const multiplier = elasticityStrategy.spec.sloOutputParams.currSloCompliancePercentage / 100;
        newScale.spec.replicas = Math.ceil(currScale.spec.replicas * multiplier);
        return Promise.resolve(newScale);
    }
    ```
    See the changes [here](https://github.com/polaris-slo-cloud/polaris-demos/commit/).



## 3. Building and deploying the Elasticity Strategy controller

1. Since Polaris CLI has generated a Dockerfile for us, we can easily build a the container image for our elasticity strategy controller.
For this tutorial, we will load the image directly into minikube.
Alternatively, we could adjust the tag of the image and push it to Dockerhub.
The tags for the image can be adjusted in the build command in `apps/my-horizontal-elasticity-strategy-controller/project.json` `targets.docker-build.options.commands` (the user friendliness of this step will be improved in the future).
When changing the tag here, you also need to change the image name in `apps/my-horizontal-elasticity-strategy-controller/manifests/kubernetes/2-slo-controller.yaml`

    ```JSON
    "commands": [
        "docker build ... -t polarissloc/horizontal-elasticity-strat-controller:latest ."
    ],
    ```

    ```sh
    # Build SLO controller container image
    polaris-cli docker-build my-horizontal-elasticity-strategy-controller

    # Load the container image into your minikube cluster
    minikube image load polarissloc/my-horizontal-elasticity-strategy-controller:latest
    ```



1. Deploy the elasticity strategy controller using Polaris CLI.

    ```sh
    # Install the MyHorizontalElasticityStrategy CRD that was generated earlier
    kubectl apply -f ./libs/mystrategies/crds/

    # Deploy the controller
    polaris-cli deploy my-horizontal-elasticity-strategy-controller

    # Verify that the deployment worked
    kubectl get deployments.apps -n polaris
    ```