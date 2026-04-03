#!/usr/bin/env bash
set -e

multipass launch --name k8s-control-plane --cpus 2 --mem 2G --disk 10G
multipass launch --name k8s-worker-1 --cpus 2 --mem 2G --disk 10G
multipass launch --name k8s-worker-2 --cpus 2 --mem 2G --disk 10G