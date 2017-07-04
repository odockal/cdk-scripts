# cdk-scripts

Script for setting up CDK 3.x environment

Script are designed to ease installation, configuration and/or cleaning up CDK 3.x environment, speccialy in jenkins job using CDK 3.x (CDK integration tests, openshift, devsuite installer).

## Operating systems
* Linux
* win and mac are planned to be supported in future`

### Prerequisites

* wget
* curl

### cdk3-install.sh

* CDK 3.x installation: downloads miinshift binary, makes it runnable and configures the environment

#### Usage

    $ cdk3-install.sh -u minishift_url -p minishift_path
* -u, --url is required parameter and expects minishift binary at the location, if there will be existing minishift file, it wil be overrided
* -p, --path is optional parameter and sets to which folder minishift will be downloaded, if it exists, minishift will be downloaded to existing folder

Script also executes 'minishift setup-cdk' in case that this command was not executed before in given environment (on the machine)

### cdk3-stop.sh

* Stops and/or delete running CDK instance of the given minishift binary path

### Usage

    $ cdk3-stop.sh -p minishift_binary
* -p, --path is a required parameter that contains path to minishift binary file

### cdk3-cleanup.sh

* Provides set of steps that should stop, delete and remove existing minishift instance and other components that was not successfully removed  on the machine in previous job. One could think of failure in job and would lead to state where minishift vm is still running, but minishift binary was deleted (clean up step in jenkins job, where workspace is erased).
In such situation, given minishift binary is downloaded via given parameter, and then 'minishift stop' and/or 'minishift delete' are executed. In cases where minishift home folder was erased (.minishift at $HOME location, or if MINISHIFT_HOME env. var was set) there is no chance to connect newly downloaded/ or existing minishift binary to running minishift vm, and clean up steps must be taken manually.

### Usage

* $ cdk3-cleanup.sh -p minishift_path -u minishift_url -h minishift_home
* -p, --path param. that is required and represents a path with minishift binary or directory where new minishift will be downloaded
* -u, --url (optional) - CDK/minishift binary url to download"
* -h, --home parameter minishift home path, overrides MINISHIFT_HOME
* -e, --erase parameter will erase minishift binary, created folders and minishift home folder"

