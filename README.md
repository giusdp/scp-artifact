**Special Requirements**: To perform the evaluation of this artefact the user needs to have access to Google Cloud Platform Compute Engine resources.

---

# Quick-start guide (Kick-the-tires phase)

The repository presents 4 folders, of which 2 needed for the deployment:

- _opentofu_: with the terraform scripts for the virtual machines deployment;
- _ansible_: with the setup and configuration of the VMs, the deployment of Kubernetes, the VPN creation and finally the tAPP-enabled OpenWhisk deployment.

The other 2 folders are:

- _bench_: with the functions used for the evaluation, a locustfile for the testing and a jupyter notebook to analyse the results;
- _scripts_: with utility scripts to setup openwhisk and run the benchmarks. These scripts are used in the setup.sh script.

There are 2 scripts in the root of the repository:

- _setup.sh_: a script that runs all the necessary steps to deploy the VMs, deploy and configure the Kubernetes cluster, deploy and configure OpenWhisk, deploy the function and run the benchmarks (using tAPP);
- _stop.sh_: a script to tear down the VMs.

By default the "setup" script will use tAPP. To run the benchmark without tAPP, use the "create_vanilla_actions.sh" script followed by the "run_locust_vanilla_functions.sh" script from the 
"scripts" folder.

The required dependencies to execute the commands are:

- [Google Cloud Platform account](https://cloud.google.com/) with a project and a service account with the necessary permissions to create Compute Engine instances and a credentials.json file;
- [Docker](https://www.docker.com/) to use the provided container equipped with an Ubuntu environment with OpenTofu, Ansible and wsk pre-installed. The system running Docker should be an x86-64 architecture. The software is not intended or tested on ARM (e.g., the latest Apple hardware) or other architectures.

A video showing a small demo is available at: https://vimeo.com/915098870

## Prepare for the VMs deployment:

Run the Docker container with the following command:

```bash
docker run -it scp-artifact bash
```

The container will start and you will be in the `/app` directory with
the repository files available.

Change directory to opentofu:

```bash
cd opentofu
```

Here the `provider.tf` script will deploy 6 machines on Google Cloud Platform, 4 in the `europe-west1-b` zone, the other 2 in the `us-central1-a` zone.

First, create a file called `terraform.tfvars` with the same content as the file `tfvars.example`:

```bash
cp tfvars.example terraform.tfvars
```

The tfvars required are:

1.  project: the Google Cloud Platform project ID;
2.  gc_user: the GCP username owner of the project;
3.  allowed_ip: the allowed IP that will be able to connect to the cluster (you can leave 0.0.0.0/0 to expose it completely);

You can edit the file with nano or vim:

```bash
nano terraform.tfvars
```

A "credentials.json" file is also needed to be present.

It can be obtained following [this guide](https://developers.google.com/workspace/guides/create-credentials). After creating a service account with Compute Engine privileges and requesting the credentials in json format.

You can copy the contents of the json file and in the opentofu folder run:

```bash
nano credentials.json
```

Then paste the content and save the file.

Finally, initialize the providers:

```bash
tofu init
```

## Run the setup:

Now that the VMs can be created on GCP, return to the root (`/app`) directory:

```bash
cd /app
```

And run the setup script:

```bash
./setup.sh
```

The creation of the VMs will take a few minutes to complete. 

Afterward, the script will run the ansible playbook to configure the machines and install OpenWhisk.
The ansible tasks can take around 15 minutes to complete. Once finished, the script will wait for an
additional 5 minutes to ensure that the OpenWhisk installation is completed.

When the ansible playbook is done, the script will 
install and configure the `wsk` CLI tool to interact with OpenWhisk
and create two functions: `refresh` and `first`.

The `refresh` function is a sample function that can be used to refresh the OpenWhisk tAPP configuration, the `first` function is used for the benchmark.

Finally, the script will run the benchmark using the `locust` tool to test the OpenWhisk deployment.
The tool will generate a `request_statistic.csv` file with the results of the benchmark, inside the `bench` folder.

#### tAPP Configurations

To change and try different tAPP configurations, you can 
configure different policies in the `configLB.yml` file located in the OpenWhisk controller persistent volume claims.

You can edit the `configLB.yml` from the OpenWhisk controllers persistent volume claims from the Kubernetes control-plane VM. To connect to it:

```bash
./connect_master.sh
```

Each OpenWhisk deployment will have a different name for the volume claim, but it will always be in the `/var/nfs/kubedata` folder starting with openwhisk-owdev-controller-.

```bash
sudo nano /var/nfs/kubedata/openwhisk-owdev-controller-<hash>/configLB.yml
```

Once the configLB.yml file is updated exit from the ssh connection with:

```bash
exit
```

From the container shell, request a refresh of the current configuration by invoking a function with the special `-p controller_config_refresh true` parameter:

```bash
wsk -i action invoke hello -p controller_config_refresh true 
```

(it might initially return error but the configuration will be updated).

Now it is possible to invoke functions using the newly updated configuration.

#### Tagged functions

To create tagged functions, the `-a` flag to add annotations at functions creation must be used. You can add the special `tag` annotation to tag a function:

```bash
wsk action create example hello.js -a tag a_policy_tag -i
```

To also make use of the modified nginx to choose specific controllers, the policy tag must be passed at invocation time as a parameter:

```bash
wsk action invoke tagged_function -p tag a_policy_tag -r -i
```

## Forbidding functions with a tAPP script

To show how to forbid the execution of a function by associating it with a policy
that has no valid workers, we will modify the `configLB.yml` file to include a new policy tag.

To do so, first, reconnect to the master machine:

```bash
./connect_master.sh
```

Re-edit the `configLB.yml` file:

```bash
sudo nano /var/nfs/kubedata/openwhisk-owdev-controller-<hash>/configLB.yml
```

And add at the end of the file:

```yaml
- another:
    - controller: "us-controller"
      workers:
        - set: "non-existent"
      topology_tolerance: "none"
  followup: fail
```

Now return to the container shell:

```bash
exit
```

And refresh the configuration:

```bash
wsk action invoke hello -p controller_config_refresh true -i
```

Now you can create a new function with the `another` tag:

```bash
wsk action create forbidden hello.js -a tag another -i
```

As before, invoke it:

```bash
wsk action invoke forbidden -p tag another -r -i
```

You should see:

```bash
error: Unable to invoke action 'forbidden' ...
```

# Clean up

To delete the cluster and remove all the machines, run the `stop.sh` script from the root folder (`/app`):

```bash
./stop.sh
```
