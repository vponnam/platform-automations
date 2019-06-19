#!/bin/bash

set -eu

vault write concourse/main/${USER}/om-user value=admin
pass=$(openssl rand -base64 24)
vault write concourse/main/${USER}/om-pass value=$pass
vault write concourse/main/${USER}/om-decrypt value=$pass
vault write concourse/main/${USER}/az value=${location}b

# ssh key-pair for the above domain
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=US/CN=${domain}" \
    -keyout pas.key  -out pas.cert

vault write concourse/main/${USER}/pas-cert value=@pas.cert
vault write concourse/main/${USER}/pas-key value=@pas.key
