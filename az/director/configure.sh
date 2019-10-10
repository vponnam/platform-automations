#!/bin/bash

set -eu

vault read --field=value concourse/main/om-ssh-private > om-ssh-key
bosh int src/az/director/secrets.yml --var-file om-ssh-key=om-ssh-key > keys.yml
bosh int <(echo "${Director_Prop}") > dir-params.yml
om --env om-configs/env.yml configure-director -c src/az/director/director.yml --vars-file dir-params.yml --vars-file keys.yml
