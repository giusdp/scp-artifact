#!/bin/bash

HOST="$(awk 'NR==2 {print $2}' ./ansible/hosts.ini | cut -d'=' -f2)"
username=$(awk -F'=' '/gc_user/ {gsub(/"/,"",$2); print $2}' ./opentofu/terraform.tfvars)

ssh -i ow-gcp-key $username@$HOST
