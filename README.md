# Ansible install k8s cluster
This is a ansible script to install k8s cluster
## Table of content
- [Supported OS](#supported-os)
- [Features](#features)
- [Usage](#usage)
## Supported OS
- [x] Ubuntu
- [ ] CentOS
## Features
- [x] Helm
- [ ] Multiple master nodes
## Usage
### 1. Create inventory file
```bash
cp inventory/example inventory/my_cluster
```
### 2. Edit inventory file
```bash
vi inventory/my_cluster
```
### 3. Run script
```bash
# Install
./run.sh -i -h inventory/my_cluster/hosts

# Uninstall
./run.sh -u -h inventory/my_cluster/hosts
```