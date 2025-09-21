# vagrant-setup

## How-to

- Create .vagrant.yml file
- Execute `vagrant-setup.sh`


## Example .vagrant.yml

```
---

vagrant_root: /data/vagrant
vagrant_project: desktop
vagrant_provider: virtualbox # or libvirt
vagrant_boxes:
  vms:
    - name: desktop-fedora37
      nested_hw_virt: on
      box: generic/fedora37
      ip: 192.168.56.101
      cpus: 2
      memory: 4096
    - name: desktop-ubuntu2204
      nested_hw_virt: on
      box: generic/ubuntu2204
      ip: 192.168.56.102
      cpus: 2
      memory: 4096
    - name: desktop-debian11
      nested_hw_virt: on
      box: generic/debian11
      ip: 192.168.56.103
      cpus: 2
      memory: 4096
  ansible:
    options:
      config_file: $PWD/ansible.cfg
      verbose: "vvv"
    host_vars:
      desktop-fedora37:
        vm_hostname: desktop-fedora37
      desktop-ubuntu2204:
        vm_hostname: desktop-ubuntu2204
      desktop-debian11:
        vm_hostname: desktop-debian11
    groups:
      mark:
        - desktop-fedora37
        - desktop-ubuntu2204
        - desktop-debian11
    group_vars:
      mark:
        var1: true
        var2: "sure"
    extra_vars:
      vm_user: vagrant
      vm_password: "$y$j9T$UsEmV3TEzbLcJDHxTrOwo1$XJQJP80b8kbFyOmO1e4GoY/gRTHg6vCv86DDiTDrn32"
    playbooks:
      - phase: bootstrap
        file: playbooks/bootstrap.yml
        run: once
      - phase: desktop
        file: playbooks/dev-vm.yml
        run: never
      - phase: desktop
        file: playbooks/dev-vm-extra.yml
        run: never
```
