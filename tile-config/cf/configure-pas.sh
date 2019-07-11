#!/bin/bash

set -eu

vault read --field=value concourse/main/vponnam/pas-cert > cert
vault read --field=value concourse/main/vponnam/pas-key > key

bosh int src/tile-config/cf/secrets.yml --var-file wildcard-cert=cert --var-file wildcard-key=key > keys.yml
bosh int <(echo "${cf_vars}") > cf-vars.yml
bosh int <(echo "${OM_ENV}") > env.yml

om --env env.yml stage-product -p cf -v ${pas_version}

bosh int src/tile-config/cf/cf-vars.yml --var-file cf-vars.yml --var-file keys.yml > vars.yml
om --env env.yml configure-product -c src/tile-config/cf/cf-properties.yml  --vars-file vars.yml
