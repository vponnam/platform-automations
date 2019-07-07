#!/bin/bash

set -eu

vault write concourse/main/${USER}/om-user value=admin
pass=$(openssl rand -base64 24)
vault write concourse/main/${USER}/om-pass value=$pass
vault write concourse/main/${USER}/om-decrypt value=$pass
vault write concourse/main/${USER}/storage-account value=${USER}storageaccount
vault write concourse/main/${USER}/resource-group value=${USER}
vault write concourse/main/${USER}/network value=$NETWORK
vault write concourse/main/${USER}/subnet value=$SUBNET


#Create the wildcard certs for app/sys domain/s
webIP=$(vault read -field=value concourse/main/${USER}/pas-web-ip)

# ssh key-pair for the above domain

openssl req -new -newkey rsa:4096 -days 3 -nodes -x509 \
  -subj "/C=US/CN=*.${webIP}.xip.io" \
  -reqexts SAN -extensions SAN -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:*.login.${webIP}.xip.io,DNS:*.uaa.${webIP}.xip.io,DNS:*.uaa.${webIP}.nip.io,DNS:*.login.${webIP}.nip.io,DNS:*.${webIP}.nip.io")) \
  -keyout pas.key  -out pas.cert

vault write concourse/main/${USER}/pas-cert value=@pas.cert
vault write concourse/main/${USER}/pas-key value=@pas.key
