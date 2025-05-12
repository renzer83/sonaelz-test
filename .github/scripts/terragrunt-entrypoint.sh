# .github/scripts/terragrunt-entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail

# 1) Configura SSH
mkdir -p ~/.ssh
eval "$(ssh-agent -s)"
printf '%s\n' "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
ssh-add ~/.ssh/id_rsa
ssh-keyscan github.com >> ~/.ssh/known_hosts

# 2) Chama o Terragrunt com todos os args que vieram do Action
exec terragrunt "$@"