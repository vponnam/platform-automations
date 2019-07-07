#!/bin/bash

set -ue

az login --service-principal -u $app_id -p $client_secret -t $tenant

#Delete OM-VM
az vm delete -g ${USER} -n opsman-${OM_VERSION} --yes

#Delete OM Nic
az network nic delete -g ${USER} -n ${OM_NIC}

#Delete OM disk
az disk delete -g ${USER} -n ${OM_DISK} --yes

#Delete image
az image delete -g ${USER} -n opsman-image-${OM_VERSION}

#Delete Public IPs
az network lb delete -g ${USER} -n pas-web-elb
az network public-ip delete -g ${USER} -n ${PAS_PUB_IP}
az network public-ip delete -g ${USER} -n ${OM_IP}

#Delete Storage Account
az storage account delete -g ${USER} -n ${USER}storageaccount --yes

#Delete vnet
az network vnet delete -g ${USER} -n ${NETWORK}

#Delete NSG
az network nsg delete -g ${USER} -n ${NSG_NAME}

#Delete RG
az group delete -n ${USER} -y

# Vault clean-up
vault delete concourse/main/${USER}/om-target
vault delete concourse/main/${USER}/om-user
vault delete concourse/main/${USER}/om-pass
vault delete concourse/main/${USER}/om-decrypt
vault delete concourse/main/${USER}/storage-account
vault delete concourse/main/${USER}/resource-group
vault delete concourse/main/${USER}/network
vault delete concourse/main/${USER}/subnet
vault delete concourse/main/${USER}/pas-web-ip
vault delete concourse/main/${USER}/pas-domain
vault delete concourse/main/${USER}/pas-cert
vault delete concourse/main/${USER}/pas-key


printf "\nSuccessfully completed clean-up process.\n"
