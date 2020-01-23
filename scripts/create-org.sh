#!/bin/bash
set -euo pipefail

echo "${0#$PWD}" >> ~/.paas-script-usage

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT=$0

# shellcheck disable=SC1090
source "${SCRIPT_DIR}/common.sh"

# Defaults
DEFAULT_SPACE=sandbox

usage() {
  cat <<EOF
Usage:

  $SCRIPT --org <orgname> --owner '<owner name>'

$SCRIPT will create an organisation in the CF service where you
are currently logged in.

The script will fail if the organisation already exists.

Requirements:

 * You must login with the cf client with an "admin" user.

Where:
  --org <orgname> Organisation to create.
  --owner <owner name> The department or authority that manages this org (see ./scripts/list-org-owners.sh for a current list)
EOF
  exit 1
}

abort_usage() {
  echo -e "${COL_RED:-}${COL_LIGHT:-}ERROR:${COL_RESET:-} $*" 1>&2
  usage
  exit 1
}

check_params_and_environment() {
  if [ -z "${ORG:-}" ] || [ -z "${OWNER:-}" ]; then
    abort_usage "Org and Owner must be defined"
  fi

  if ! cf orgs >/dev/null 2>&1; then
    abort "You need to be logged into CF CLI"
  fi

  if [[ "$(cf api)" =~ https://api.cloud.service.gov.uk ]]; then
    read -p 'New orgs should be created in London by default. Are you sure? [Yy]' -r
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      echo
      echo -e -n "${COL_GREEN:-}"
      echo "Creating org in Ireland"
      echo -e -n "${COL_RESET:-}"
      echo
    else
      >&2 echo
      >&2 echo -e -n "${COL_RED:-}"
      >&2 echo "Exitting. Please login to London: cf login -a https://api.london.cloud.service.gov.uk --sso"
      >&2 echo -e -n "${COL_RESET:-}"
      exit 1
    fi
  fi
}

check_owner_name() {
  if ! OWNER_FULL_NAME="$(ruby ./scripts/find-gov-department-name.rb "${OWNER}")"; then
    exit 1
  fi

  OWNER="${OWNER_FULL_NAME}"
}

create_org_space() {
  if cf org "${ORG}" 2&> /dev/null; then
    >&2 echo "The organisation ${ORG} already exists. Aborting."
    exit 1
  fi
  cf create-org "${ORG}"

  # annotate the org with it's owner
  cf curl "/v3/organizations/$(cf org "${ORG}" --guid)" -d '{"metadata":{"annotations":{"owner":"'"${OWNER}"'"}}}' -X PATCH

  cf create-space "${DEFAULT_SPACE}" -o "${ORG}"

  # cf create-{org|space} has the side-effect of giving roles in the org/space
  # to the user making the request. We don't want this, so have to undo it.
  local admin_user
  admin_user=$(cf target | awk 'tolower($0)~/user:/ { print $2}')
  cf unset-org-role "${admin_user}" "${ORG}" OrgManager
  cf unset-space-role "${admin_user}" "${ORG}" "${DEFAULT_SPACE}" SpaceManager
  cf unset-space-role "${admin_user}" "${ORG}" "${DEFAULT_SPACE}" SpaceDeveloper

  # Even after losing all the roles, user is still present in the list of all users of an org
  # FIXME: remove this fix for https://github.com/cloudfoundry/cli/issues/781 is deployed
  guid=$(cf org "${ORG}" --guid)
  cf curl -X DELETE "/v2/organizations/${guid}/users" -d "{\"username\": \"${admin_user}\"}"
}

prompt_to_invite_user() {
  if [ -z "${guid:-}" ]; then
    >&2 echo 'Expected guid not to be empty. Aborting'
    exit 1
  fi
  echo '******************************************'
  echo 'Organisation created.'
  echo
  echo 'Please create invite the required users to this organisation using paas admin by visiting:'
  echo
  echo -e -n "${COL_BLUE:-}"
  echo "$(cf target | sed -n 's|api endpoint: *https://api.|https://admin.|p')/organisations/${guid}/users/invite"
  echo -e -n "${COL_RESET:-}"
  echo
  echo '******************************************'
  read -p 'Please confirm that you have invited the users. [Yy]' -r
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo
    echo -e -n "${COL_GREEN:-}"
    echo "Thank you"
    echo -e -n "${COL_RESET:-}"
    echo
  else
    >&2 echo
    >&2 echo -e -n "${COL_RED:-}"
    >&2 echo "Ok, you really should invite the users though, otherwise this is all a bit pointless."
    >&2 echo -e -n "${COL_RESET:-}"
    exit 1
  fi
}

prompt_to_add_user_to_mailing_list() {
  echo -e "******************************************
As a new account has been created please remember to update the
gov-uk-paas-announce mailing list. You can do that by inviting the user to the
group by using this URL:

${COL_BLUE:-}https://groups.google.com/a/digital.cabinet-office.gov.uk/forum/#!managemembers/gov-uk-paas-announce/invite${COL_RESET:-}

As a welcome message you can use the text from here:

${COL_BLUE:-}https://groups.google.com/a/digital.cabinet-office.gov.uk/forum/#!forum/gov-uk-paas-announce${COL_RESET:-}

******************************************"
  read -p 'Please confirm that you have added the users to the mailing list. [Yy]' -r
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo
    echo -e -n "${COL_GREEN:-}"
    echo "Good job - have a nice day"
    echo -e -n "${COL_RESET:-}"
  else
    >&2 echo
    >&2 echo -e -n "${COL_RED:-}"
    >&2 echo "Ok, you really should add the users though, or they won't get their emails."
    >&2 echo -e -n "${COL_RESET:-}"
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  key="$1"
  shift
  case $key in
    --org)
      ORG="$1"
      shift
    ;;
    --owner)
      OWNER="$1"
      shift
      if [[ "$OWNER" == *"@"* ]]; then
        >&2 echo "--owner $OWNER should be the name of the department or authority that manages this org, not the email of the owner"
        exit 1
      fi
    ;;
    *)
      # unknown option
      usage
    ;;
  esac
done

load_colors
check_params_and_environment
check_owner_name
create_org_space
prompt_to_invite_user
prompt_to_add_user_to_mailing_list
