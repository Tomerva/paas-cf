#!/bin/bash

set -eu
RELEASE=0.2.3
PINGDOM_TF_VERSION=0.11.1
BINARY=terraform-provider-pingdom-tf-${PINGDOM_TF_VERSION}-$(uname -s)-$(uname -m)

# Setup the working grounds.
PAAS_DIR=$(pwd)
WORKING_DIR=$(mktemp -d terraform-lint.XXXXXX)
trap 'rm -r "${PAAS_DIR}/${WORKING_DIR}"' EXIT

wget "https://github.com/alphagov/paas-terraform-provider-pingdom/releases/download/${RELEASE}/${BINARY}" \
  -O "${WORKING_DIR}"/terraform-provider-pingdom
chmod +x "${WORKING_DIR}"/terraform-provider-pingdom

cd "${WORKING_DIR}"

for dir in "${PAAS_DIR}"/terraform/*/ ; do
  [[ ${dir} == *"terraform/providers"* ]] && continue
  [[ ${dir} == *"terraform/scripts"* ]] && continue
  [[ ${dir} == *"terraform/spec"* ]] && continue

  terraform init -backend=false "${dir}" >/dev/null
  terraform validate -check-variables=false "${dir}"
done

terraform fmt -check -diff "${PAAS_DIR}/terraform"
