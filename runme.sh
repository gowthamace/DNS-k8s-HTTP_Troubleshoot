#!/bin/bash

#---------------------------------------------#
# Author: Gowtham
#---------------------------------------------#

# --- COLOR PROFILES ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

LAB_DIR="lab"
CLUSTER_NAME="GS-lab"

clear_active_topology() {
    echo -e "${YELLOW}🧹 Clearing active scenario topology to avoid collisions...${NC}"
    kubectl delete deployment,service,ingress --all --grace-period=0 --force 2>/dev/null
    sleep 2
}

print_header() {
    clear
    echo -e "${CYAN}=========================================================${NC}"
    echo -e "    🚀  K8s HTTP HANDSHAKE WORKSHOP UTILITY     "
    echo -e "${CYAN}=========================================================${NC}"
}

print_usage() {
    echo -e "Usage: $0 [option]"
    echo -e "\nOptions:"
    echo -e "  --setup        Configure KinD Cluster & Networking Mesh on EC2"
    echo -e "  --scenario-1  Deploy Healthy Baseline (200 OK)"
    echo -e "  --scenario-2  Deploy Protocol Redirection (301 Moved Permanently)"
    echo -e "  --scenario-3  Deploy Identity Authorization Deficiencies (401 Unauthorized)"
    echo -e "  --scenario-4  Deploy Missing Endpoints / Assets (404 Not Found)"
    echo -e "  --scenario-5  Deploy Application Exceptions (500 Internal Server Error)"
    echo -e "  --scenario-6  Deploy Immediate Runtime Crashes (502 Bad Gateway)"
    echo -e "  --scenario-7  Deploy Infrastructure Orchestration Dropouts (503 Service Unavailable)"
    echo -e "  --cleanup      Tear Down Cluster and Restore Baseline Environment"
}

verify_directory_structure() {
    if [ "$1" != "--setup" ] && [ "$1" != "--cleanup" ] && [ ! -d "$LAB_DIR" ]; then
        echo -e "${RED}❌ Error: Cannot find the '${LAB_DIR}/' folder!${NC}"
        echo -e "${YELLOW}Please make sure you are executing this script from the directory containing the 'lab' folder.${NC}"
        exit 1
    fi
}

get_pod_name() {
    kubectl get pods -l app=GS-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
    kubectl get pods -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "GS-pod"
}

get_ingress_name() {
    kubectl get ingress -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "GS-ingress"
}

print_playbook_header() {
    echo -e "${YELLOW}⌛ Syncing cluster configuration assets...${NC}"
    sleep 3
    
    echo -e "\n${YELLOW}💡 WORKSHOP TROUBLESHOOTING PLAYBOOK:${NC}"
    echo -e "🔹 Step 1: Execute Client Request to Trigger the Error State"
    echo -e "    ${CYAN}curl -i http://localhost${NC}"
}

setup_infrastructure() {
    print_header
    if [ ! -d "$LAB_DIR" ]; then mkdir -p "$LAB_DIR"; fi

    echo -e "${YELLOW}🧹 Purging any conflicting existing cluster topologies...${NC}"
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null

    echo -e "${YELLOW}🚀 Creating a fresh KinD engine on EC2...${NC}"
    kind create cluster --name "$CLUSTER_NAME" --config=- << 'EOF'
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

    echo -e "\n${YELLOW}🌐 Deploying KinD-Compatible NGINX Ingress Controller...${NC}"
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    echo -e "${YELLOW}⏳ Waiting for Ingress Controller deployment rollout...${NC}"
    # Wait for the API server to create and deploy the pods safely
    kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=300s

    echo -e "\n${GREEN}[✔] KinD Cluster & EC2 Host Network Bridges Operational!${NC}\n"
}

run_scenario_1() {
    print_header; clear_active_topology
    echo -e "\n${GREEN}▶ SCENARIO 1: The Healthy Baseline (200 OK)${NC}\n"
    kubectl apply -f "$LAB_DIR/1-healthy-200.yaml"
    kubectl wait --for=condition=available --timeout=60s deployment --all 2>/dev/null
    sleep 3
    echo -e "${YELLOW}💡 STUDENT VERIFICATION STEP:${NC}"
    echo -e "👉 Test inside EC2 instance:\n    ${CYAN}curl -iv http://localhost${NC}"
    echo -e "👉 Test from external machine/browser:\n    ${CYAN}curl -iv http://$(curl -s checkip.amazonaws.com)${NC}\n"
}

run_scenario_2() {
    print_header; clear_active_topology
    echo -e "\n${GREEN}▶ SCENARIO 2: Protocol Redirection (301 Moved Permanently)${NC}\n"
    kubectl apply -f "$LAB_DIR/2-redirect-301.yaml"
    print_playbook_header
    echo -e "🔹 Step 2: Follow the Redirect Path Automatically (-L flag)\n    ${CYAN}curl -ivL http://localhost${NC}"
    echo -e "🔹 Step 3: Audit Ingress Redirect Rules Configuration\n    ${CYAN}kubectl get ingress wezva-ingress -o yaml | grep -A 2 annotations${NC}\n"
    echo -e "🔹 FIX THE PROBLEM: Remove annotation line from the Ingress resource\n    ${CYAN}kubectl annotate ingress wezva-ingress nginx.ingress.kubernetes.io/permanent-redirect-${NC}\n"
}

run_scenario_3() {
    print_header; clear_active_topology
    echo -e "\n${GREEN}▶ SCENARIO 3: Identity Authorization Deficiencies (401 Unauthorized)${NC}\n"
    kubectl apply -f "$LAB_DIR/3-client-401.yaml"
    print_playbook_header
    echo -e "🔹 Step 2: Inspect App Authorization Rejection Context\n    ${CYAN}kubectl logs $(kubectl get pods -l app=GS-app -o jsonpath='{.items[0].metadata.name}')${NC}"
    echo -e "🔹 FIX THE PROBLEM: Test with Authorization Header\n    ${CYAN}curl -iv -H 'Authorization: Bearer secret-token' http://localhost${NC}\n"
}

run_scenario_4() {
    print_header; clear_active_topology
    echo -e "\n${GREEN}▶ SCENARIO 4: Missing Endpoints / Assets (404 Not Found)${NC}\n"
    kubectl apply -f "$LAB_DIR/4-client-404.yaml"
    print_playbook_header
    echo -e "🔹 Step 2: Check Application Server Logs for Unmapped Routes\n    ${CYAN}kubectl logs $(kubectl get pods -l app=GS-app -o jsonpath='{.items[0].metadata.name}')${NC}\n"
    echo -e "🔹 FIX THE PROBLEM: Curl the target with the Endpoint\n    ${CYAN}curl -i http://localhost/healthz${NC}\n"
}

run_scenario_5() {
    print_header; clear_active_topology
    echo -e "\n${GREEN}▶ SCENARIO 5: Application Exceptions (500 Internal Server Error)${NC}\n"
    kubectl apply -f "$LAB_DIR/5-server-500.yaml"
    print_playbook_header
    echo -e "🔹 Step 2: Check Application Server Logs for Crash Log Trace\n    ${CYAN}kubectl logs $(kubectl get pods -l app=GS-app -o jsonpath='{.items[0].metadata.name}')${NC}\n"
    echo -e "🔹 FIX THE PROBLEM: Inject Environment Variable \n    ${CYAN}kubectl set env deployment/wezva-deployment DATABASE_URL="postgres://user:pass@db:5432/wezva"${NC}\n"
}

run_scenario_6() {
    print_header; clear_active_topology
    echo -e "\n${GREEN}▶ SCENARIO 6: Immediate Runtime Crashes (502 Bad Gateway)${NC}\n"
    kubectl apply -f "$LAB_DIR/6-badgateway-502.yaml"
    print_playbook_header
    echo -e "🔹 Step 2: Validate Service Endpoints & Port Mappings \n    ${CYAN}kubectl get endpoints wezva-service${NC}"
    echo -e "🔹 Step 3: Check Ingress Proxy Controller Error Sockets\n    ${CYAN}kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=20 | grep -i error${NC}\n"
    echo -e "🔹 FIX THE PROBLEM: Patch the service to Target port 8080 \n    ${CYAN}kubectl patch service GS-service --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value": 8080}]' \n    kubectl annotate ingress GS-ingress ingress.kubernetes.io/reload="$(date +%s)" --overwrite ${NC}\n"
}

run_scenario_7() {
    print_header; clear_active_topology
    echo -e "\n${GREEN}▶ SCENARIO 7: Infrastructure Orchestration Dropouts (503 Service Unavailable)${NC}\n"
    kubectl apply -f "$LAB_DIR/7-serviceunavailable-503.yaml"
    echo -e "${YELLOW}🔧 Injecting intentional Service Selector Mismatch...${NC}"
    sleep 2
    kubectl patch service wezva-service -p '{"spec":{"selector":{"app":"fallback-handler"}}}' 2>/dev/null
    print_playbook_header
    echo -e "🔹 Step 2: Verify Missing active Service Endpoints (Will show '<none>')\n    ${CYAN}kubectl get endpoints GS-service${NC}"
    echo -e "🔹 Step 3: Check Pod Label Selectors and Health Status\n    ${CYAN}kubectl get pods --show-labels${NC}\n"
    echo -e "🔹 FIX THE PROBLEM: Apply the correct label selector on the service \n    ${CYAN}kubectl patch service wezva-service -p '{\"spec\":{\"selector\":{\"app\":\"wezva-app\"}}}'${NC}\n"
}

cleanup_environment() {
    print_header
    echo -e "${RED}⚠️  De-registering Lab Environment...${NC}"
    kind delete cluster --name "$CLUSTER_NAME"
    echo -e "\n${GREEN}[✔] Cluster components destroyed cleanly.${NC}\n"
}

# --- PROCESS STARTER ---
if [ -z "$1" ]; then
    print_header
    print_usage
    exit 0
fi

verify_directory_structure "$1"

case "$1" in
    --setup)        setup_infrastructure ;;
    --scenario-1)   run_scenario_1 ;;
    --scenario-2)   run_scenario_2 ;;
    --scenario-3)   run_scenario_3 ;;
    --scenario-4)   run_scenario_4 ;;
    --scenario-5)   run_scenario_5 ;;
    --scenario-6)   run_scenario_6 ;;
    --scenario-7)   run_scenario_7 ;;
    --cleanup)      cleanup_environment ;;
    *)
        print_header
        echo -e "${RED}❌ Invalid Option Selected: '$1'${NC}\n"
        print_usage
        exit 1
        ;;
esac

