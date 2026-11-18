#!/usr/bin/env bash
# Canary for the report. It shows that this file from the pull request ran, and which account the
# credential belongs to that actions/checkout left in the checkout's git config (actions/checkout v7
# writes it to a file that .git/config includes). It never prints or sends the credential: it only
# uses it to read the account name, the token scopes and the account's permissions on this
# repository from api.github.com.
set -u
cd "${BUILD_WORKSPACE_DIRECTORY:-.}"
echo "CANARY: tools/canary.sh from the pull request is running as //tools:requirements.update (workflow: ${GITHUB_WORKFLOW:-?}, event: ${GITHUB_EVENT_NAME:-?}, triggered by: ${GITHUB_ACTOR:-?})"
header=$(git config --get-regexp '^http\..*\.extraheader$' 2>/dev/null | head -n 1 | cut -d' ' -f2-)
if [ -z "$header" ]; then
  echo "CANARY: git config has no credential for this checkout"
  exit 0
fi
tmp=$(mktemp -d)
if curl -fsS -D "$tmp/headers" -o "$tmp/user.json" -H "$header" https://api.github.com/user; then
  login=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["login"])' "$tmp/user.json")
  scopes=$(grep -i '^x-oauth-scopes:' "$tmp/headers" | cut -d: -f2- | tr -d '\r' | sed 's/^ *//')
  echo "CANARY: the credential that actions/checkout left in git config belongs to ${login}, token scopes: ${scopes:-none}"
  if curl -fsS -o "$tmp/repo.json" -H "$header" "https://api.github.com/repos/${GITHUB_REPOSITORY:-}"; then
    perms=$(python3 -c 'import json, sys; p = json.load(open(sys.argv[1]))["permissions"]; print(", ".join(k + "=" + str(v).lower() for k, v in sorted(p.items())))' "$tmp/repo.json")
    echo "CANARY: permissions of ${login} on this repository: ${perms}"
  fi
else
  echo "CANARY: git config has a credential for this checkout, but the API call with it failed"
fi
rm -rf "$tmp"
