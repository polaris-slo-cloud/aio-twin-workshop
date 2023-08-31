# Polaris Workshop at AIoTwin Summer School 2023

This is the tutorial for the [Polaris SLO Framework](https://github.com/polaris-slo-cloud/polaris-slo-framework) workshop held at the [AIoTwin Summer School 2023](https://www.aiotwin.eu/aiotwin/activities/summer_schools/1st_summer_school).


## Prerequisites

Before starting the tutorial, please clone this repository and install the [prerequisites](./prerequisites).


## Tutorial

1. To begin the tutorial, install the [Polaris CLI](https://www.npmjs.com/package/@polaris-sloc/cli).

    ```sh
    npm install -g @polaris-sloc/cli
    ```

2. Create a new workspace using the CLI:

    ```sh
    polaris-cli init workshop
    cd workshop
    ```

3. Continue with the tutorial to implement [custom horizontal elasticity strategy](./01-horizontal-elasticity-strategy.md).

4. Implement and configure an [Average CPU Usage SLO](./02-avg-cpu-slo.md) for a workload.
