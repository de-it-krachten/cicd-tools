#!/bin/bash

ansible-playbook /data/git/git-tools/cicd/ansible-role/ci-init-convert.yml -e working_dir=$PWD
