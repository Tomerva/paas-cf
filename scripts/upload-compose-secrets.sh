#!/bin/sh

set -eu

export PASSWORD_STORE_DIR=${COMPOSE_PASSWORD_STORE_DIR}

COMPOSE_ACCESS_TOKEN=$(pass "compose/integration_tests/access_token")

SECRETS=$(mktemp secrets.yml.XXXXXX)
trap 'rm  "${SECRETS}"' EXIT

cat > "${SECRETS}" << EOF
---
compose_access_token: ${COMPOSE_ACCESS_TOKEN}
EOF

aws s3 cp "${SECRETS}" "s3://gds-paas-${DEPLOY_ENV}-state/compose-broker-secrets.yml"
