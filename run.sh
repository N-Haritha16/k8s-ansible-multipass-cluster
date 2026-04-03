#!/usr/bin/env bash
set -e

docker-compose up -d --build

docker exec ansible-controller bash -c "/provision_vms.sh"

docker exec ansible-controller ansible-playbook site.yml