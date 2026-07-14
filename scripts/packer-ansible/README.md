# Packer + Ansible Docker Image Builder

## Prerequisites
- [Packer](https://developer.hashicorp.com/packer/install) >= 1.9.0
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) >= 2.14
- Docker

## Usage

### 1. Install Packer plugins
```bash
packer init build.pkr.hcl
```

### 2. Validate the template
```bash
packer validate build.pkr.hcl
```

### 3. Build with defaults
```bash
packer build build.pkr.hcl
```

### 4. Build with custom variables
```bash
packer build -var-file=variables.pkrvars.hcl build.pkr.hcl
```

### 5. Build with inline override
```bash
packer build -var="image_tag=3.0" build.pkr.hcl
```

## Project Structure
```
packer-ansible/
├── build.pkr.hcl           # Packer template
├── variables.pkrvars.hcl   # Variable overrides
├── playbook.yml            # Ansible provisioning playbook
├── README.md
└── app/
    ├── main.py             # Sample app entry point
    └── requirements.txt    # Python dependencies
```
