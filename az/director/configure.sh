#!/bin/bash

set -eu



vault read --field=value concourse/main/om-ssh-private > om-ssh-key
bosh int <(echo "${Director_Prop}") --var-file ssh-key=om-ssh-key > dir-params.yml
om --env om-configs/env.yml configure-director -c src/az/director/director.yml --vars-file dir-params.yml
