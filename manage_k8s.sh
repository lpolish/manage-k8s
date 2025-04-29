#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_NAME=$(basename "$0")
KUBE_CONTEXT=$(kubectl config current-context 2>/dev/null)
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOGFILE="/tmp/k8s_manage_${TIMESTAMP}.log"

# Logging function
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        *)
            echo "[$level] $message"
            ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOGFILE"
}

# Check if kubectl is installed
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log "ERROR" "kubectl could not be found. Please install kubectl first."
        exit 1
    fi
}

# Check Kubernetes connection
check_k8s_connection() {
    if ! kubectl cluster-info &> /dev/null; then
        log "ERROR" "Unable to connect to Kubernetes cluster. Please check your configuration."
        exit 1
    fi
}

# Display help
show_help() {
    echo -e "${GREEN}Kubernetes Management Script${NC}"
    echo "Usage: $SCRIPT_NAME [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  list-apps           List all deployed applications"
    echo "  app-status [APP]    Show detailed status of a specific application"
    echo "  cluster-status      Show cluster health and resource usage"
    echo "  deploy [FILE]       Deploy a new application from YAML file"
    echo "  delete [APP]        Delete an application"
    echo "  scale [APP] [NUM]   Scale an application to NUM replicas (0 to pause)"
    echo "  restart [APP]       Restart an application"
    echo "  logs [APP]          Show logs for an application"
    echo "  exec [APP] [CMD]    Execute a command in the application's container"
    echo "  port-forward [APP] [LOCAL:REMOTE] Set up port forwarding"
    echo "  backup [NAMESPACE]  Backup all resources in a namespace"
    echo "  list-ns             List all namespaces"
    echo "  cleanup             Cleanup completed/failed pods"
    echo "  help                Show this help message"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE  Specify namespace (default: current context namespace)"
    echo "  -a, --all-namespaces       Operate across all namespaces"
    echo "  -v, --verbose              Show verbose output"
    echo "  -h, --help                 Show help for specific command"
    echo ""
    echo "Current context: ${KUBE_CONTEXT:-None}"
    exit 0
}

# List all deployed applications
list_apps() {
    local namespace_arg=$([[ -n "$NAMESPACE" ]] && echo "-n $NAMESPACE" || echo "--all-namespaces")
    
    log "INFO" "Listing deployed applications..."
    
    echo -e "${YELLOW}DEPLOYMENTS:${NC}"
    kubectl get deployments $namespace_arg -o wide 2>&1 | tee -a "$LOGFILE"
    
    echo -e "\n${YELLOW}STATEFULSETS:${NC}"
    kubectl get statefulsets $namespace_arg -o wide 2>&1 | tee -a "$LOGFILE"
    
    echo -e "\n${YELLOW}DAEMONSETS:${NC}"
    kubectl get daemonsets $namespace_arg -o wide 2>&1 | tee -a "$LOGFILE"
    
    echo -e "\n${YELLOW}PODS:${NC}"
    kubectl get pods $namespace_arg -o wide 2>&1 | tee -a "$LOGFILE"
    
    echo -e "\n${YELLOW}SERVICES:${NC}"
    kubectl get services $namespace_arg -o wide 2>&1 | tee -a "$LOGFILE"
    
    echo -e "\n${YELLOW}INGRESSES:${NC}"
    kubectl get ingress $namespace_arg -o wide 2>&1 | tee -a "$LOGFILE"
}

# Show application status
app_status() {
    if [[ -z "$1" ]]; then
        log "ERROR" "Application name not provided. Usage: $SCRIPT_NAME app-status [APP]"
        exit 1
    fi
    
    local app=$1
    local namespace_arg=$([[ -n "$NAMESPACE" ]] && echo "-n $NAMESPACE" || echo "")
    
    log "INFO" "Getting status for application: $app"
    
    # Check if the resource exists
    if ! kubectl get deployment "$app" $namespace_arg &> /dev/null && \
       ! kubectl get statefulset "$app" $namespace_arg &> /dev/null && \
       ! kubectl get daemonset "$app" $namespace_arg &> /dev/null; then
        log "ERROR" "Application '$app' not found in namespace '${NAMESPACE:-default}'"
        exit 1
    fi
    
    echo -e "${YELLOW}BASIC INFO:${NC}"
    kubectl get all $namespace_arg | grep "$app" 2>&1 | tee -a "$LOGFILE"
    
    echo -e "\n${YELLOW}DETAILED STATUS:${NC}"
    kubectl describe deployment "$app" $namespace_arg 2>&1 | tee -a "$LOGFILE"
    kubectl describe statefulset "$app" $namespace_arg 2>&1 | tee -a "$LOGFILE"
    kubectl describe daemonset "$app" $namespace_arg 2>&1 | tee -a "$LOGFILE"
    
    echo -e "\n${YELLOW}PODS:${NC}"
    kubectl get pods $namespace_arg -l app="$app" -o wide 2>&1 | tee -a "$LOGFILE"
    
    echo -e "\n${YELLOW}EVENTS:${NC}"
    kubectl get events $namespace_arg --field-selector involvedObject.name="$app" 2>&1 | tee -a "$LOGFILE"
    
    echo -e "\n${YELLOW}RESOURCE USAGE:${NC}"
    local pods=$(kubectl get pods $namespace_arg -l app="$app" -o jsonpath='{.items[*].metadata.name}')
    for pod in $pods; do
        echo -e "\nPod: $pod"
        kubectl top pod "$pod" $namespace_arg 2>&1 | tee -a "$LOGFILE"
    done
}

# Show cluster status
cluster_status() {
    log "INFO" "Getting cluster status..."
    
    echo -e "${YELLOW}NODES:${NC}"
    kubectl get nodes -o wide 2>&1 | tee -a "$LOGFILE"
    
    echo -e "\n${YELLOW}NODE RESOURCE USAGE:${NC}"
    kubectl top nodes 2>&1 | tee -a "$LOGFILE"
    
    echo -e "\n${YELLOW}CLUSTER INFO:${NC}"
    kubectl cluster-info 2>&1 | tee -a "$LOGFILE"
    
    echo -e "\n${YELLOW}COMPONENT STATUS:${NC}"
    kubectl get componentstatuses 2>&1 | tee -a "$LOGFILE"
    
    echo -e "\n${YELLOW}RESOURCE CAPACITY:${NC}"
    kubectl get pod,svc,ing,deploy,sts,ds,pvc --all-namespaces 2>&1 | tee -a "$LOGFILE"
}

# Deploy application
deploy_app() {
    if [[ -z "$1" ]]; then
        log "ERROR" "YAML file not provided. Usage: $SCRIPT_NAME deploy [FILE]"
        exit 1
    fi
    
    local file=$1
    local namespace_arg=$([[ -n "$NAMESPACE" ]] && echo "-n $NAMESPACE" || echo "")
    
    if [[ ! -f "$file" ]]; then
        log "ERROR" "File $file not found"
        exit 1
    fi
    
    log "INFO" "Deploying application from $file..."
    kubectl apply -f "$file" $namespace_arg 2>&1 | tee -a "$LOGFILE"
    
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log "SUCCESS" "Application deployed successfully"
        # Get the name of the deployed resource
        local app_name=$(grep -m1 -E '^(kind:|name:)' "$file" | awk '/name:/ {print $2}')
        if [[ -n "$app_name" ]]; then
            sleep 3  # Wait a bit for resources to initialize
            app_status "$app_name"
        fi
    else
        log "ERROR" "Failed to deploy application"
    fi
}

# Delete application
delete_app() {
    if [[ -z "$1" ]]; then
        log "ERROR" "Application name not provided. Usage: $SCRIPT_NAME delete [APP]"
        exit 1
    fi
    
    local app=$1
    local namespace_arg=$([[ -n "$NAMESPACE" ]] && echo "-n $NAMESPACE" || echo "")
    
    log "INFO" "Deleting application: $app"
    
    # Check if the resource exists
    if kubectl get deployment "$app" $namespace_arg &> /dev/null; then
        kubectl delete deployment "$app" $namespace_arg 2>&1 | tee -a "$LOGFILE"
    elif kubectl get statefulset "$app" $namespace_arg &> /dev/null; then
        kubectl delete statefulset "$app" $namespace_arg 2>&1 | tee -a "$LOGFILE"
    elif kubectl get daemonset "$app" $namespace_arg &> /dev/null; then
        kubectl delete daemonset "$app" $namespace_arg 2>&1 | tee -a "$LOGFILE"
    else
        log "ERROR" "Application '$app' not found in namespace '${NAMESPACE:-default}'"
        exit 1
    fi
    
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log "SUCCESS" "Application $app deleted successfully"
    else
        log "ERROR" "Failed to delete application $app"
    fi
}

# Scale application
scale_app() {
    if [[ -z "$1" || -z "$2" ]]; then
        log "ERROR" "Application name or replica count not provided. Usage: $SCRIPT_NAME scale [APP] [NUM]"
        exit 1
    fi
    
    local app=$1
    local replicas=$2
    local namespace_arg=$([[ -n "$NAMESPACE" ]] && echo "-n $NAMESPACE" || echo "")
    
    log "INFO" "Scaling application $app to $replicas replicas..."
    
    # Check if the resource exists
    if kubectl get deployment "$app" $namespace_arg &> /dev/null; then
        kubectl scale deployment "$app" --replicas="$replicas" $namespace_arg 2>&1 | tee -a "$LOGFILE"
    elif kubectl get statefulset "$app" $namespace_arg &> /dev/null; then
        kubectl scale statefulset "$app" --replicas="$replicas" $namespace_arg 2>&1 | tee -a "$LOGFILE"
    else
        log "ERROR" "Application '$app' not found in namespace '${NAMESPACE:-default}'"
        exit 1
    fi
    
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        if [[ "$replicas" -eq 0 ]]; then
            log "SUCCESS" "Application $app paused (scaled to 0 replicas)"
        else
            log "SUCCESS" "Application $app scaled to $replicas replicas"
        fi
    else
        log "ERROR" "Failed to scale application $app"
    fi
}

# Restart application
restart_app() {
    if [[ -z "$1" ]]; then
        log "ERROR" "Application name not provided. Usage: $SCRIPT_NAME restart [APP]"
        exit 1
    fi
    
    local app=$1
    local namespace_arg=$([[ -n "$NAMESPACE" ]] && echo "-n $NAMESPACE" || echo "")
    
    log "INFO" "Restarting application: $app"
    
    # Check if the resource exists
    if kubectl get deployment "$app" $namespace_arg &> /dev/null; then
        kubectl rollout restart deployment "$app" $namespace_arg 2>&1 | tee -a "$LOGFILE"
    elif kubectl get statefulset "$app" $namespace_arg &> /dev/null; then
        kubectl rollout restart statefulset "$app" $namespace_arg 2>&1 | tee -a "$LOGFILE"
    elif kubectl get daemonset "$app" $namespace_arg &> /dev/null; then
        kubectl rollout restart daemonset "$app" $namespace_arg 2>&1 | tee -a "$LOGFILE"
    else
        log "ERROR" "Application '$app' not found in namespace '${NAMESPACE:-default}'"
        exit 1
    fi
    
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log "SUCCESS" "Application $app restart initiated"
        sleep 3
        app_status "$app"
    else
        log "ERROR" "Failed to restart application $app"
    fi
}

# Show application logs
show_logs() {
    if [[ -z "$1" ]]; then
        log "ERROR" "Application name not provided. Usage: $SCRIPT_NAME logs [APP]"
        exit 1
    fi
    
    local app=$1
    local namespace_arg=$([[ -n "$NAMESPACE" ]] && echo "-n $NAMESPACE" || echo "")
    
    log "INFO" "Showing logs for application: $app"
    
    # Get the first pod matching the app label
    local pod=$(kubectl get pod $namespace_arg -l app="$app" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -z "$pod" ]]; then
        log "ERROR" "No pods found for application '$app' in namespace '${NAMESPACE:-default}'"
        exit 1
    fi
    
    kubectl logs "$pod" $namespace_arg --tail=50 -f 2>&1 | tee -a "$LOGFILE"
}

# Execute command in application container
exec_in_app() {
    if [[ -z "$1" || -z "$2" ]]; then
        log "ERROR" "Application name or command not provided. Usage: $SCRIPT_NAME exec [APP] [CMD]"
        exit 1
    fi
    
    local app=$1
    local cmd=$2
    local namespace_arg=$([[ -n "$NAMESPACE" ]] && echo "-n $NAMESPACE" || echo "")
    
    log "INFO" "Executing command in application: $app"
    
    # Get the first pod matching the app label
    local pod=$(kubectl get pod $namespace_arg -l app="$app" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -z "$pod" ]]; then
        log "ERROR" "No pods found for application '$app' in namespace '${NAMESPACE:-default}'"
        exit 1
    fi
    
    kubectl exec -it "$pod" $namespace_arg -- $cmd 2>&1 | tee -a "$LOGFILE"
}

# Set up port forwarding
port_forward() {
    if [[ -z "$1" || -z "$2" ]]; then
        log "ERROR" "Application name or port mapping not provided. Usage: $SCRIPT_NAME port-forward [APP] [LOCAL:REMOTE]"
        exit 1
    fi
    
    local app=$1
    local ports=$2
    local namespace_arg=$([[ -n "$NAMESPACE" ]] && echo "-n $NAMESPACE" || echo "")
    
    log "INFO" "Setting up port forwarding for application: $app"
    
    # Get the first pod matching the app label
    local pod=$(kubectl get pod $namespace_arg -l app="$app" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -z "$pod" ]]; then
        log "ERROR" "No pods found for application '$app' in namespace '${NAMESPACE:-default}'"
        exit 1
    fi
    
    kubectl port-forward "$pod" $namespace_arg "$ports" 2>&1 | tee -a "$LOGFILE"
}

# Backup namespace resources
backup_namespace() {
    local namespace=$1
    if [[ -z "$namespace" ]]; then
        namespace_arg=$([[ -n "$NAMESPACE" ]] && echo "$NAMESPACE" || echo "default")
        log "WARNING" "No namespace specified, using '$namespace_arg'"
    else
        namespace_arg=$namespace
    fi
    
    local backup_file="k8s_backup_${namespace_arg}_${TIMESTAMP}.yaml"
    
    log "INFO" "Backing up resources in namespace: $namespace_arg to $backup_file"
    
    kubectl get all -n "$namespace_arg" -o yaml > "$backup_file" 2>&1 | tee -a "$LOGFILE"
    kubectl get configmap,secret -n "$namespace_arg" -o yaml >> "$backup_file" 2>&1 | tee -a "$LOGFILE"
    
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log "SUCCESS" "Backup completed successfully: $backup_file"
    else
        log "ERROR" "Failed to complete backup"
    fi
}

# List all namespaces
list_namespaces() {
    log "INFO" "Listing all namespaces..."
    kubectl get namespaces -o wide 2>&1 | tee -a "$LOGFILE"
}

# Cleanup completed/failed pods
cleanup_pods() {
    local namespace_arg=$([[ -n "$NAMESPACE" ]] && echo "-n $NAMESPACE" || echo "--all-namespaces")
    
    log "INFO" "Cleaning up completed/failed pods..."
    
    # Delete completed pods
    kubectl delete pod $namespace_arg --field-selector=status.phase==Succeeded 2>&1 | tee -a "$LOGFILE"
    
    # Delete failed pods
    kubectl delete pod $namespace_arg --field-selector=status.phase==Failed 2>&1 | tee -a "$LOGFILE"
    
    log "SUCCESS" "Cleanup completed"
}

# Main script execution
main() {
    check_kubectl
    check_k8s_connection
    
    # Parse global options first
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -a|--all-namespaces)
                NAMESPACE=""
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                if [[ -z "$2" ]]; then
                    show_help
                else
                    # Show command-specific help
                    case "$2" in
                        list-apps|app-status|cluster-status|deploy|delete|scale|restart|logs|exec|port-forward|backup|list-ns|cleanup)
                            "$2"_help
                            exit 0
                            ;;
                        *)
                            show_help
                            ;;
                    esac
                fi
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Parse command
    case "$1" in
        list-apps)
            list_apps
            ;;
        app-status)
            app_status "$2"
            ;;
        cluster-status)
            cluster_status
            ;;
        deploy)
            deploy_app "$2"
            ;;
        delete)
            delete_app "$2"
            ;;
        scale)
            scale_app "$2" "$3"
            ;;
        restart)
            restart_app "$2"
            ;;
        logs)
            show_logs "$2"
            ;;
        exec)
            exec_in_app "$2" "${@:3}"
            ;;
        port-forward)
            port_forward "$2" "$3"
            ;;
        backup)
            backup_namespace "$2"
            ;;
        list-ns)
            list_namespaces
            ;;
        cleanup)
            cleanup_pods
            ;;
        help)
            show_help
            ;;
        *)
            log "ERROR" "Invalid command. Use '$SCRIPT_NAME help' for usage information."
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"