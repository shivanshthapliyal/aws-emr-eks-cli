#!/bin/bash

# Determine the shell environment
if [ -n "$ZSH_VERSION" ]; then
    SHELL_TYPE="zsh"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_TYPE="bash"
else
    echo "Unsupported shell. Please use bash or zsh."
    exit 1
fi

# Globals and Constants
CONFIG_FILE="$HOME/.emr_eks_config"
OUTPUT_DIR="/tmp/emr_eks_cli"

# Auto-Completion Setup
## Auto-Completion Setup for Zsh
if [[ "$SHELL_TYPE" == "zsh" ]]; then
    _emr_eks_completion() {
        local -a commands=('fetch-virtual-clusters' 'describe-job' 'cancel-job' 'clone-job' 'get-pods' 'list-running-jobs')
        if (( CURRENT == 2 )); then
            compadd -a commands
        elif (( CURRENT > 2 )); then
            case $words[2] in
                describe-job|cancel-job|clone-job|get-pods|list-running-jobs)
                    _emr_job_complete_zsh
                    ;;
            esac
        fi
    }

    _emr_job_complete_zsh() {
        if [[ ! -f "$CONFIG_FILE" ]]; then
            echo "Configuration file not found. Please run 'emr-eks fetch-virtual-clusters' first."
            return 1
        fi

        local -a eks_names=($(jq -r '.[].EKS' "$CONFIG_FILE" | uniq))
        local -a virtual_names=($(jq -r '.[].Name' "$CONFIG_FILE" | uniq))

        if (( CURRENT == 3 )); then
            compadd -a eks_names
        elif (( CURRENT == 4 )); then
            compadd -a virtual_names
        fi
    }

    autoload -Uz compinit && compinit
    compdef _emr_eks_completion emr-eks
elif [ "$SHELL_TYPE" = "bash" ]; then # Auto-Completion Setup for Bash
    _emr_eks_completion() {
        local current_word="${COMP_WORDS[COMP_CWORD]}"
        local commands="fetch-virtual-clusters describe-job cancel-job clone-job get-pods llist-running-jobs"

        if [[ "$COMP_CWORD" == "1" ]]; then
            COMPREPLY=($(compgen -W "$commands" -- "$current_word"))
        elif [[ "$COMP_CWORD" == "2" ]]; then
            COMPREPLY=($(compgen -W "$(jq -r '.[].EKS' "$CONFIG_FILE" | uniq)" -- "$current_word"))
        elif [[ "$COMP_CWORD" == "3" ]]; then
            COMPREPLY=($(compgen -W "$(jq -r '.[].Name' "$CONFIG_FILE" | uniq)" -- "$current_word"))
        fi
    }
    complete -F _emr_eks_completion emr-eks
fi

# AWS CLI Queries
# QUERY_VIRTUAL_CLUSTERS="virtualClusters[].{EKS:containerProvider.id, Name:name, ID:id}"
QUERY_VIRTUAL_CLUSTERS="virtualClusters[].{EKS:containerProvider.id, Name:name, ID:id, Namespace:containerProvider.info.eksInfo.namespace}"
QUERY_CLUSTER_ID="virtualClusters[?name=='%s'&&containerProvider.id=='%s'].{id:id}"

# Function to fetch virtual clusters and save them
fetch_virtual_clusters() {
    local clusters=$(aws emr-containers list-virtual-clusters --query "$QUERY_VIRTUAL_CLUSTERS" --output json)
    if [ -z "$clusters" ]; then
        echo "Failed to fetch virtual clusters. Check your AWS CLI configuration and permissions."
        return 1
    fi
    echo "$clusters" >| "$CONFIG_FILE"
    echo "Virtual clusters data saved to $CONFIG_FILE"
}

# Function to get namespace for a specific virtual cluster
get_namespace_from_virtual_cluster() {
    local eks_cluster_name="$1"
    local cluster_name="$2"
    local namespace=$(jq -r --arg eks "$eks_cluster_name" --arg cluster "$cluster_name" \
        '.[] | select(.EKS == $eks and .Name == $cluster) | .Namespace' "$CONFIG_FILE")
    
    if [ -z "$namespace" ]; then
        echo "Namespace not found for virtual cluster $cluster_name in EKS cluster $eks_cluster_name."
        return 1
    fi
    
    echo "$namespace"
}

# Describe job function
describe_job() {
    if [ "$#" -ne 3 ]; then
        echo "Usage: describe-job <eks_cluster_name> <virtual_cluster_name> <JOB_ID>"
        return 1
    fi

    local eks_cluster_name="$1"
    local cluster_name="$2"
    local JOB_ID="$3"
    local cluster_info=$(get_cluster_id_from_file "$eks_cluster_name" "$cluster_name")
    if [ -z "$cluster_info" ]; then
        return 1
    fi

    mkdir -p "$OUTPUT_DIR"
    local output_file="$OUTPUT_DIR/${cluster_info}-$JOB_ID.json"
    if ! aws emr-containers describe-job-run --virtual-cluster-id "$cluster_info" --id "$JOB_ID" > "$output_file"; then
        echo "Failed to fetch job description."
        return 1
    fi
    echo "Job description saved to $output_file"
    # Open with default editor or command, adjust for environment
    if [ "$SHELL_TYPE" = "zsh" ]; then
        cat "$output_file"
        # code "$output_file" # opens in vs-code
    elif [ "$SHELL_TYPE" = "bash" ]; then
        cat "$output_file"
        # ${EDITOR:-vi} "$output_file" # opens in vi
    fi
}

# Function to list pods for a specific EMR on EKS job
get_pods() {
    if [ "$#" -ne 3 ]; then
        echo "Usage: get_pods <eks_cluster_name> <virtual_cluster_name> <job_id>"
        return 1
    fi

    local eks_cluster_name="$1"
    local cluster_name="$2"
    local job_id="$3"
    local label_selector="emr-containers.amazonaws.com/job.id=$job_id"

    # Get namespace from the virtual cluster configuration
    local namespace=$(get_namespace_from_virtual_cluster "$eks_cluster_name" "$cluster_name")
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Check if the context exists
    if ! kubectl config get-contexts -o name | grep -q "^$eks_cluster_name\$"; then
        echo "Context '$eks_cluster_name' not found."
        echo "Would you like to create it with the alias '$eks_cluster_name'? (y/n)"
        read user_response
        if [[ "$user_response" == "y" ]]; then
            echo "Creating context '$eks_cluster_name'..."
            if ! aws eks update-kubeconfig --name "$eks_cluster_name" --alias "$eks_cluster_name"; then
                echo "Failed to create context for EKS cluster $eks_cluster_name. Please check your AWS credentials and cluster name."
                return 1
            fi
            echo "Context '$eks_cluster_name' successfully created."
        else
            echo "Operation cancelled by the user. Please create the context manually if needed."
            return 1
        fi
    fi

    # Set the context to the specific EKS cluster
    if ! kubectl config use-context "$eks_cluster_name"; then
        echo "Failed to set context to EKS cluster $eks_cluster_name"
        return 1
    fi

    # List pods using the label selector and name regex
    local pods=$(kubectl get pods -n "$namespace" --selector="$label_selector" -o json | jq -r '.items[] | select(.metadata.name | test("'"$job_id"'")) | .metadata.name')
    if [ -z "$pods" ]; then
        echo "No pods found for job with label $label_selector or name matching regex '$job_id' in namespace $namespace."
        return 1
    fi

    # echo "Pods running for job with label $label_selector or name matching regex '$job_id' in namespace $namespace:"
    echo ""

    # Print pod details without headers
    echo "$pods" | xargs -I {} kubectl top pod {} -n "$namespace" --no-headers | column -t
}

cancel_job() {
    if [[ "$#" -ne 3 ]]; then
        echo "Usage: cancel-job <eks_cluster_name> <virtual_cluster_name> <job_id>"
        return 1
    fi

    local eks_cluster_name="$1"
    local virtual_cluster_name="$2"
    local job_id="$3"
    local cluster_info=$(get_cluster_id_from_file "$eks_cluster_name" "$virtual_cluster_name")
    if [[ -z "$cluster_info" ]]; then
        return 1
    fi

    local cancel_command="aws emr-containers cancel-job-run --id $job_id --virtual-cluster-id $cluster_info"
    eval $cancel_command
    if [[ "$?" -ne 0 ]]; then
        echo "Failed to cancel job $job_id."
        return 1
    fi
    echo "Job $job_id has been successfully cancelled."
}

clone_job() {
    if [[ "$#" -ne 3 ]]; then
        echo "Usage: clone-job <eks_cluster_name> <virtual_cluster_name> <JOB_ID>"
        return 1
    fi

    local eks_cluster_name="$1"
    local cluster_name="$2"
    local JOB_ID="$3"
    local cluster_info=$(get_cluster_id_from_file "$eks_cluster_name" "$cluster_name")
    if [ -z "$cluster_info" ]; then
        return 1
    fi

    local output_file="$OUTPUT_DIR/$cluster_info-$JOB_ID.json"
    if [ ! -f "$output_file" ]; then
        echo "Output file does not exist: $output_file"
        return 1
    fi

    local job_name=$(jq -r '.jobRun.name' "$output_file")
    local job_role_arn=$(jq -r '.jobRun.executionRoleArn' "$output_file")
    local job_release_label=$(jq -r '.jobRun.releaseLabel' "$output_file")
    local job_driver=$(jq -r '.jobRun.jobDriver' "$output_file" | jq .)
    local tags=$(jq -r '.jobRun.tags' "$output_file" | jq .)
    local retry_policy=$(jq -r '.jobRun.retryStrategy' "$output_file" | jq .)
    local job_configuration_overrides=$(jq -r '.jobRun.configurationOverrides' "$output_file" | jq .)

    local start_job_run_command=$(cat <<-END
aws emr-containers start-job-run \\
  --virtual-cluster-id $cluster_info \\
  --name '$job_name' \\
  --execution-role-arn $job_role_arn \\
  --release-label $job_release_label \\
  --job-driver '$job_driver' \\
  --tags '$tags' \\
  --retry-strategy '$retry_policy' \\
  --configuration-overrides '$job_configuration_overrides'
END
    )

    echo "Generated start-job-run command:"
    echo "$start_job_run_command"
    # Uncomment to execute the command automatically
    # eval "$start_job_run_command"
}

# Function to fetch and list running jobs in a virtual cluster
list_running_jobs() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: list-running-jobs <eks_cluster_name> <virtual_cluster_name>"
        return 1
    fi

    local eks_cluster_name="$1"
    local virtual_cluster_name="$2"
    local namespace=$(get_namespace_from_virtual_cluster "$eks_cluster_name" "$virtual_cluster_name")
    if [ -z "$namespace" ]; then
        return 1
    fi

    local virtual_cluster_id=$(jq -r --arg eks "$eks_cluster_name" --arg cluster "$virtual_cluster_name" \
        '.[] | select(.EKS == $eks and .Name == $cluster) | .ID' "$CONFIG_FILE")
    if [ -z "$virtual_cluster_id" ]; then
        echo "Virtual cluster ID not found for $virtual_cluster_name in EKS cluster $eks_cluster_name."
        return 1
    fi

    local running_jobs=$(aws emr-containers list-job-runs --virtual-cluster-id "$virtual_cluster_id" --query 'jobRuns[?state==`RUNNING`].{Id:id,Name:name}' --output json)
    if [ -z "$running_jobs" ]; then
        echo "No running jobs found for virtual cluster $virtual_cluster_name."
        return 1
    fi

    echo "Running jobs in virtual cluster $virtual_cluster_name:"
    echo -e "JOB_ID\tJOB_NAME"
    echo "$running_jobs" | jq -r '.[] | "\(.Id)\t\(.Name)"' | column -t -s $'\t'
}

# Helper Functions
get_cluster_id_from_file() {
    local eks_cluster_name="$1"
    local cluster_name="$2"
    local jq_query=".[] | select(.Name == \"$cluster_name\" and .EKS == \"$eks_cluster_name\") | .ID"

    local cluster_id=$(jq -r "$jq_query" "$CONFIG_FILE")
    
    if [[ "$cluster_id" == "null" || -z "$cluster_id" ]]; then
        echo "No virtual cluster found with name: $cluster_name on EKS cluster: $eks_cluster_name in the local cache."
        return 1
    fi

    echo "$cluster_id"
}
