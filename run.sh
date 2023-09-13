#!/bin/bash

# Check if Ansible is installed
if ! command -v ansible-playbook &>/dev/null; then
  echo "ansible-playbook could not be found."
  exit 1
fi

INVENTORY=""

# Function to run the install playbook
install_playbook() {
  ansible-playbook playbooks/install.yaml -i "${INVENTORY}"
}

# Function to run the uninstall playbook
uninstall_playbook() {
  ansible-playbook playbooks/uninstall.yaml -i "${INVENTORY}"
}

# Parse command-line arguments
while getopts "iuh:" option; do
  case $option in
  i)
    OPERATION="install"
    ;;
  u)
    OPERATION="uninstall"
    ;;
  h)
    INVENTORY="$OPTARG"
    ;;
  *)
    echo "Usage: ./run.sh [-i | -u] -h <inventory_file>"
    exit 1
    ;;
  esac
done

# Check if an operation and inventory are provided
if [[ -z ${OPERATION} || -z ${INVENTORY} ]]; then
  echo "Usage: ./run.sh [-i | -u] -h <inventory_file>"
  exit 1
fi

if [[ ${OPERATION} == "install" ]]; then
  install_playbook
elif [[ ${OPERATION} == "uninstall" ]]; then
  uninstall_playbook
fi
