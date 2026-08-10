#!/bin/bash
set -e

# Terraform
wget -q -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
sudo apt-get update -qq
sudo apt-get install -y -qq terraform 2>&1 | tail -3

# shellcheck
sudo apt-get install -y -qq shellcheck 2>&1 | tail -2

# hadolint (binario directo)
sudo curl -fsSL -o /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64
sudo chmod +x /usr/local/bin/hadolint

# gh CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubarch-archive-keyring.gpg 2>/dev/null
sudo chmod go+r /usr/share/keyrings/githubarch-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubarch-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update -qq
sudo apt-get install -y -qq gh 2>&1 | tail -2

# jq y herramientas útiles
sudo apt-get install -y -qq jq yamllint 2>&1 | tail -2

echo "ALL_TOOLS_INSTALLED"
echo "---"
echo "terraform:  $(terraform --version | head -1)"
echo "shellcheck: $(shellcheck --version | grep -m1 version)"
echo "hadolint:   $(hadolint --version)"
echo "gh:         $(gh --version | head -1)"
echo "yamllint:   $(yamllint --version)"
