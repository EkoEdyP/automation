```
ansible-project/
├── ansible.cfg          # Project-specific configuration
├── inventories/         # Separate inventories per environment
│   ├── staging/         # Staging-specific hosts and variables
│   │   ├── hosts.yml
│   │   └── group_vars/  # Vars specifically for staging groups
│   └── production/      # Production-specific hosts and variables
│       ├── hosts.yml
│       └── group_vars/
├── group_vars/          # Global variables for all environments
│   └── all.yml          # Truly global, non-sensitive settings
├── playbooks/           # Focused playbooks for different tasks
│   ├── site.yml         # Master playbook including others
│   ├── webservers.yml
│   └── dbservers.yml
├── roles/               # Reusable, modular components
│   ├── common/          # Base setup for every server
│   ├── nginx/           # Web server configuration
│   └── postgres/        # Database configuration
├── library/             # Custom local Ansible modules
├── collections/         # Custom or downloaded collections
├── requirements.yml     # External role/collection dependencies
└── Makefile             # Shortcuts for common commands (optional)
```