## Automated Kubernetes Cluster with Ansible and Multipass

This project automates the provisioning of a multi‑node Kubernetes cluster using Ansible, kubeadm, and local Ubuntu VMs created with Multipass. It also builds and deploys a sample web application to the cluster, including a simulated rolling update and final HTTP validation.

## Architecture Overview

3 Ubuntu 22.04 VMs created by Multipass:

k8s-control-plane – Kubernetes control plane node.

k8s-worker-1 – Worker node.

k8s-worker-2 – Worker node.

An Ansible controller container (via docker-compose.yml) runs all playbooks and kubectl commands.

Kubernetes is bootstrapped with kubeadm, using containerd as the container runtime and a CNI plugin (Calico or Flannel).

A sample Flask web app is containerized and deployed with a Deployment + NodePort Service, then updated with a rolling update.

## High‑level flow:

Provision 3 Multipass VMs.

Prepare nodes (swap off, kernel modules, sysctl, containerd).

Install kubeadm, kubelet, kubectl.

Initialize control plane and capture join command.

Join workers.

Install CNI and wait for all nodes to be Ready.

Deploy sample app, perform rolling update, and validate HTTP access.

## Repository Structure
text
.
├── README.md
├── .env.example
├── Dockerfile.ansible          # Image for ansible-controller
├── docker-compose.yml          # Starts ansible-controller container
├── provision_vms.sh            # Provisions Multipass VMs
├── run.sh                      # Single entrypoint script
├── app/
│   ├── app.py                  # Sample Flask app
│   ├── requirements.txt        # Python dependencies
│   └── Dockerfile              # Builds app image
└── ansible/
    ├── ansible.cfg
    ├── inventory/
    │   └── inventory.yml       # Dynamic inventory of VMs
    ├── site.yml                # Main playbook
    └── roles/
        ├── common/             # Prereqs + containerd + kube tools
        ├── control-plane/      # kubeadm init + join command capture
        ├── workers/            # Join workers to cluster
        ├── cni/                # Install CNI plugin
        └── app-deploy/         # App deploy, rolling update, validation
This structure follows the assignment’s requirements for roles, inventory, controller container, and scripts.

## Prerequisites
On the host machine (where Multipass runs):

OS: Windows, macOS, or Linux with:

Multipass installed and working (multipass version, multipass launch).

Docker and Docker Compose installed.

Internet access to:

https://cloud-images.ubuntu.com (for VM images).

Docker Hub (or your container registry).

Environment:

Docker Desktop running (on Windows/macOS).

Sufficient resources (recommended):

8 GB RAM or more.

Enough disk space for 3 VMs (each 2 CPUs, 2 GB RAM, 10 GB disk).

Configuration
Clone the repository:

bash
git clone https://github.com/N-Haritha16/k8s-ansible-multipass-cluster.git
cd k8s-ansible-multipass-cluster
Create .env from the example:

bash
cp .env.example .env
Edit .env and set values:

Examples:

text
K8S_VERSION=1.28.2-00
DOCKERHUB_USER=your-dockerhub-username
APP_IMAGE_TAG=v1.0.0
APP_IMAGE_TAG_NEW=v1.0.1
These variables are used in Ansible roles and Docker build/push logic.

How to Run (Single Command Flow)
All steps can be triggered from the host with one script, as required by the assignment.

Ensure Multipass works on this machine:

bash
multipass launch 22.04 --name test-vm --cpus 1 --memory 1G --disk 5G
multipass delete test-vm
multipass purge
Start the Ansible controller and run the full automation:

bash
./run.sh
run.sh performs:

docker-compose up --build to start ansible-controller.

Invokes provision_vms.sh to create:

k8s-control-plane

k8s-worker-1

k8s-worker-2

Executes the main Ansible playbook inside the controller container:

bash
ansible-playbook ansible/site.yml
If your environment requires a different entry command, adjust run.sh accordingly.

Ansible Roles and Playbooks
common role
Responsible for preparing all nodes:

Disable swap (swapoff -a and update /etc/fstab).

Load kernel modules (overlay, br_netfilter).

Set sysctl parameters:

net.bridge.bridge-nf-call-iptables=1

net.ipv4.ip_forward=1

Install and configure containerd.

Add Kubernetes APT repo and GPG key.

Install kubeadm, kubelet, kubectl (pinned to K8S_VERSION), and hold packages.

control-plane role
Runs only on k8s-control-plane:

Execute kubeadm init with appropriate --pod-network-cidr for the chosen CNI.

Make admin.conf available for the regular user ($HOME/.kube/config).

Run kubeadm token create --print-join-command and register the join command in a variable to be reused by worker nodes.

workers role
Runs on k8s-worker-1 and k8s-worker-2:

Execute the captured join command from the control-plane role.

Ensure idempotency by skipping join if node is already part of the cluster.

cni role
Installs the CNI plugin (Calico or Flannel):

Applies the CNI manifest using either the k8s module or kubectl apply -f.

Ensures CNI pods in kube-system namespace are running.

app-deploy role
Handles application deployment and validation:

Build/push the sample app image (if integrated with Docker within the controller).

Apply Kubernetes Deployment and NodePort Service manifests (deployment.yml, service.yml).

Perform a rolling update by changing the image tag to APP_IMAGE_TAG_NEW.

Wait for rollout completion and fail on any rollout error.

Perform a final HTTP request (e.g., via uri module) against the NodePort on a worker node IP, checking for HTTP 200.

site.yml
Top‑level playbook that orchestrates roles in order:

Run common on all nodes.

Run control-plane on the control plane node.

Run workers on worker nodes.

Run cni from the control plane.

Validate all nodes are Ready.

Run app-deploy to deploy and test the application.

Verification Steps
After run.sh completes successfully:

Get nodes from the control plane:

bash
multipass shell k8s-control-plane
kubectl get nodes
You should see k8s-control-plane, k8s-worker-1, and k8s-worker-2 in Ready state.

Check workloads:

bash
kubectl get pods -A
kubectl get deployments
kubectl get services
Test NodePort service from host:

bash
# Example: worker node IP and NodePort from service
curl http://<worker-node-ip>:<nodeport>
You should see the sample app’s response (e.g., “Hello from <hostname>”).

Notes and Limitations
The project assumes Multipass is functional on the host; if Multipass cannot launch instances (e.g., due to backend/cache issues), the automation cannot create the VMs required by the assignment.

You can swap CNI (Calico/Flannel) by changing the manifest used by the cni role and updating --pod-network-cidr accordingly.

For production use, further hardening (RBAC, TLS, backups, monitoring) should be added; this repository focuses on meeting the lab’s core automation requirements.

