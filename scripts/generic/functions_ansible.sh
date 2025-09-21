
# Read requirements.yml and retrieves all external roles

function Requirements_yaml
{

  local Reqfile=$1

  # Check for requirements.yml format
  # This can be a list or consist of the nested list 'roles'
  if yq -j .roles $Reqfile >/dev/null 2>&1
  then
    Roles=$(yq -j .roles $Reqfile | jq -r '.[] | @base64')
  else
    Roles=$(yq -j . $Reqfile | jq -r '.[] | @base64')
  fi
  
  # Loop over all roles from requirements.yml
  for row in $Roles
  do
    role=$(echo ${row} | base64 --decode | jq -r .name 2>/dev/null | sed "s/null//")
    [[ -z $role ]] && role=$(echo ${row} | base64 --decode | jq -r .role 2>/dev/null | sed "s/null//")
    [[ -z $role ]] && role=$(echo ${row} | base64 --decode | jq -r .name 2>/dev/null | sed "s/null//")
    [[ -z $role ]] && role=$(echo ${row} | base64 --decode | jq -r .src 2>/dev/null | sed "s/null//")
    [[ -z $role ]] && role=$(echo ${row} | base64 --decode)
    echo "$role"
  done

}


# Processes requirements.yml including dependencies

function Yamlloop
{

  # Get list of all roles
  Requirements_yaml $Reqfile > ${TMPFILE}1

  # Now search for all role dependencies
  for Role in `cat ${TMPFILE}1`
  do
    if [[ -f ${Path}roles/$Role/meta/requirements.yml ]]
    then
      Requirements_yaml ${Path}roles/$Role/meta/requirements.yml > ${TMPFILE}2
    fi
  done

  # Display a list of all unique role names
  cat ${TMPFILE}1 ${TMPFILE}2 2>/dev/null | sort -u

}


# Add all external roles to .gitignore

function Gitignore
{

  if ! grep -q "^roles/${Role}$" .gitignore
  then
    [[ $Verbose == true ]] && echo "Appending 'roles/${Role}' to .gitignore"
    echo "roles/${Role}" >> .gitignore
  fi

  if ! grep -q "^roles/${Role}/$" .gitignore
  then
    [[ $Verbose == true ]] && echo "Appending 'roles/${Role}/' to .gitignore"
    echo "roles/${Role}/" >> .gitignore
  fi

}


# Add all external roles to .ansible-lint

function Ansible_lint
{

  # Get current list of exclude_paths
  yq -y .exclude_paths .ansible-lint 2>/dev/null | grep -v "\[\]" | sed "s/.*- //" | grep -v "^playbooks/" > ${TMPFILE}1

  # Append all roles
  echo "$Roles" | xargs -n1 echo | sed "s/^/roles\//;s/$/\//" >> ${TMPFILE}1

  # Get all symlinks
  Links=$(ls -d playbooks/roles playbooks/*/roles playbooks/*/*/roles 2>/dev/null | sed "s/$/\//")

  # Create JSON array/lists
  if [[ -s ${TMPFILE}1 ]]
  then
    echo -e "---\n" > ${TMPFILE}2
    cat ${TMPFILE}1 | sort -u | sed "s/^/- /" >> ${TMPFILE}2
  else
    echo -e "---\n[]" > ${TMPFILE}2
  fi 
  export j2_roles="json:`yq -j -c . ${TMPFILE}2`"

  echo -e "---\n" > ${TMPFILE}2
  [[ -z $Links ]] && echo "[]" >> ${TMPFILE}2 || echo $Links | xargs -n1 echo | sort -u | sed "s/^/- /" >> ${TMPFILE}2
  export j2_links="json:`yq -j -c . ${TMPFILE}2`"

  # Create .ansible-lint from j2 template
  cp ${DIRNAME}/ansible-lint.j2 /tmp
  e2j2 -f /tmp/ansible-lint.j2
  cp /tmp/ansible-lint .ansible-lint

}

function Ansible_type
{

  # Check if a playbook repository
  if [[ -d roles || -d group_vars || -d playbooks ]] 
  then
    Ansible_repo_type=playbook
  elif [[ -f meta/main.yml ]]
  then
    Ansible_repo_type=role
  else
    echo "Unable to identify as playbook or role repository" >&2
    exit 1
  fi

}

function Dependencies
{

  echo -e "---\ncollections:\n  - community.docker" > ${TMPFILE}
  [[ -f .collections ]] && yq -y . .collections | grep "^  - " >> ${TMPFILE}
  ansible-galaxy collection install -r ${TMPFILE}

}

function Galaxy_legacy
{

  # Fall back onto old galaxy
  __ansible_version=$(ansible --version | awk 'NR==1' | awk '{print $NF}' | cut -f1,2 -d.)
  if [[ $__ansible_version =~ ^2\.(9|10|11) ]]
  then

    TMPFILE=${TMPFILE:-`mktemp`}

    echo "*** Falling back onto old Galaxy server ***"
    echo -e "[galaxy]\nserver = https://old-galaxy.ansible.com/\n" > ${TMPFILE}ansible.cfg

    export ANSIBLE_CONFIG=${TMPFILE}ansible.cfg

  fi

}

