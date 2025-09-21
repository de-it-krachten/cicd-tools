# Docker build tools

The docker build tools will make it easy to create a docker image using Ansible.
This way, you do not have to put all the logic into the Dockerfile but can do it via Ansible.

## How does it work:

1. A docker image is created using the Dockerfile template within your project.
2. A Docker container is spun-up from this newly created image.
3. The running container is altered by executing the Ansible playbooks against this container.
4. When the playbook is finished, a final image is created from the running container.


## Initialize

- Create a new directory and make it the working directory

- Initialize that directory with templates
```
docker-init.sh
```


- Edit all container setting in file 'docker-settings.yml'

- Edit 'Dockerfile.j2' to reflect all that you do not want or cannot do via Ansible in the next phase.

- Edit 'build-custom.yml' with any changes using Ansible

- Edit requirements.yml to include all roles your 'build-custom.yml' requires

Test image creation process by staring the build
```
docker-build.sh
```

Final image can be push to Docker registry
```
docker-build.sh -B -p
```
