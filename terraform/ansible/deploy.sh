#!/bin/bash
set -e

if [ -f .env ]; then
    source .env
else
    echo ".env file not found"
    echo "Create a .env file with: export GITHUB_TOKEN=<token>"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN not defined in .env"
    exit 1
fi

echo "Executing Ansible playbook..."
ansible-playbook -i inventory.yml playbook.yml "$@"

echo "Deploy successful!"