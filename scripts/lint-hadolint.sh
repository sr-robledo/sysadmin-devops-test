#!/bin/bash
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
hadolint --config .hadolint.yaml app/Dockerfile
echo "hadolint exit: $?"
