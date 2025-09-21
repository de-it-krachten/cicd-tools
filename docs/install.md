# Installation

All scripts have been packaged for the most common Linux distro.<br>
They are present as DEB or RPM package under `releases`.<br>

Alternatively, you can use the `install.sh` script in the root of the repo.

## Python virtual environment

After installing the code onto your workstation or runner, you will have a script that will set-up multiple python virtual environments. At this time of writing, the following ansible venvs will be setup:

- Ansible core 2.16 (latest version to support client with python 3.6)
- Ansible core 2.19 
- Ansible 9 (based on core 2.16 and with most collections)
- Ansible 12 (based on core 2.19 and with most collections)


| **environment**   | **name**       | **location**                        |
|-------------------|----------------|-------------------------------------|
| ansible 9         | ansible9       | /opt/cicd-tools/venv/ansible9       |
| ansible 12        | ansible12      | /opt/cicd-tools/venv/ansible12      |
| ansible core 2.16 | ansiblecore216 | /opt/cicd-tools/venv/ansiblecore216 |
| ansible core 2.19 | ansiblecore219 | /opt/cicd-tools/venv/ansiblecore219 |


To install this set of virtual environments:

````
/usr/local/bin/python-setup-venvs.sh --sudo /opt/cicd-tools/venv
````

To activate a specific environment (e.g. ansible9)
````
source /opt/cicd-tools/venv/ansible9/bin/activate
````
