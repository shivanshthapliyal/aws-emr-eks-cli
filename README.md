
# AWS emr-eks CLI

<!-- [![GitHub stars](https://img.shields.io/github/stars/shivanshthapliyal/aws-emr-eks-cli)](https://github.com/shivanshthapliyal/aws-emr-eks-cli/stargazers) [![GitHub forks](https://img.shields.io/github/forks/shivanshthapliyal/aws-emr-eks-cli)](https://github.com/shivanshthapliyal/aws-emr-eks-cli/network) [![GitHub issues](https://img.shields.io/github/issues/shivanshthapliyal/aws-emr-eks-cli)](https://github.com/shivanshthapliyal/aws-emr-eks-cli/issues)  -->
[![GitHub license](https://img.shields.io/github/license/shivanshthapliyal/aws-emr-eks-cli)](https://github.com/shivanshthapliyal/aws-emr-eks-cli/blob/main/LICENSE)

EMR-EKS is a command-line interface (CLI) tool created to simplify the management of AWS EMR jobs on EKS. It offers user-friendly commands for managing virtual clusters, describing, canceling, and cloning job runs, all with the convenience of built-in command autocompletion to enhance the user experience.


- [Installation](#installation)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)
  
<!-- ![Demo](docs/demo.gif) -->

  
## Installation

### Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) must be configured with appropriate permissions.
- [jq](https://jqlang.github.io/jq/download/) must be installed for JSON processing.

### Quickstart

#### Auto Installation

Run the Quick Installation Script:

```bash
git clone https://github.com/shivanshthapliyal/aws-emr-eks-cli.git
cd aws-emr-eks-cli
./install.sh
```

This script will set the necessary permissions, add the CLI to your PATH, and verify the setup.

#### Manual Installation
If you want to manually install, see [Manual Installation](#manual-installation). 

## Usage

To use aws emr-eks cli, you can run the `emr-eks` command followed by subcommands:

```bash
emr-eks <command> [options]
```

### Available Commands

| Command                     | Arguments                                     | Description                                                      |
| --------------------------- | --------------------------------------------- | ---------------------------------------------------------------- |
| `fetch-virtual-clusters`    | None                                          | Fetches and saves the virtual clusters available in your AWS account. |
| `list-running-jobs`         | `<eks_cluster_name> <virtual_cluster_name>` <br> *(This information can be autocompleted using TAB once `fetch-virtual-clusters` has run once.)* | Lists the running jobs in the specified EKS cluster and virtual cluster. |
| `describe-job`              | `<eks_cluster_name> <virtual_cluster_name> <JOB_ID>` | Describes a specific job identified by JOB_ID.                    |
| `cancel-job`                | `<eks_cluster_name> <virtual_cluster_name> <job_id>` | Cancels a specific job.                                           |
| `clone-job`                 | `<eks_cluster_name> <virtual_cluster_name> <JOB_ID>` | Clones a specific job.                                            |
| `get_pods`                  | `<eks_cluster_name> <virtual_cluster_name> <job_id>` | Retrieves pods related to the specified job.                      |



### Examples

```bash
# Fetching Virtual Clusters for auto-completions
emr-eks fetch-virtual-clusters

# List running jobs on a virtual cluster 
emr-eks list-running-jobs myekscluster myvirtualcluster

# Get Pods for a job
emr-eks get-pods myekscluster myvirtualcluster 000000012thisisajobID

# Describing a Job
emr-eks describe-job myekscluster myvirtualcluster 000000012thisisajobID

# Cancelling a Job
emr-eks cancel-job myekscluster myvirtualcluster 000000012thisisajobID

# Cloning a Job
emr-eks clone-job myekscluster myvirtualcluster 000000012thisisajobID
```

### Manual Installation

1. **Clone the Repository**
    ```bash
    git clone https://github.com/shivanshthapliyal/aws-emr-eks-cli.git
    cd aws-emr-eks-cli
    ```
2. **Set Executable Permissions**
    
    Make the script executable:

    ```bash
    chmod +x bin/emr-eks
    ```

3. **Add the Script to Your PATH**

    Optionally, you can add the tool to your system's PATH to use it from anywhere:
    ```bash
    echo 'export PATH="$PATH:/path/to/aws-emr-eks-cli/bin"' >> ~/.zshrc
    source ~/.zshrc
    ```

    Replace `/path/to/aws-emr-eks-cli` with the actual path to the `bin` directory in your cloned repository.


### Supported shell for autocompletion

For now, I could only develop autocompletions for following:
- bash
- zsh 

## Contributing

Contributions are welcome! Please fork the repository and open a pull request with your improvements.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE) file for details.
