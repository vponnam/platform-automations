#!/bin/bash

set -xu

vault read --field=value concourse/main/vponnam/pas-cert > cert
vault read --field=value concourse/main/vponnam/pas-key > key

bosh int src/tile-config/cf/secrets.yml --var-file wildcard-cert=cert --var-file wildcard-key=key > keys.yml
bosh int <(echo "${cf_vars}") > cf-vars.yml
bosh int <(echo "${OM_ENV}") > env.yml

om --env env.yml stage-product -p cf -v ${pas_version}
om --env env.yml configure-product -c src/tile-config/cf/cf-properties.yml  --vars-file src/tile-config/cf/cf-vars.yml  --vars-file cf-vars.yml  --vars-file keys.yml
