#!/bin/bash

set -ue

#Delete OM-VM
az vm delete -g ${USER} -n ${OM_VM_NAME} --yes

#Delete OM Nic
az network nic delete -g ${USER} -n ${OM_NIC}

#Delete OM disk
az disk delete -g ${USER} -n ${OM_DISK} --yes 

#Delete image
az image delete -g ${USER} -n opsman-image-${OM_VERSION}

#Delete Public IPs
az network public-ip delete -g ${USER} -n ${PAS_PUB_IP}
az network public-ip delete -g ${USER} -n ${OM_IP}

#Delete Storage Account
az storage account delete -g ${USER} -n ${STORAGE_ACC_NAME} --yes

#Delete vnet
az network vnet delete -g ${USER} -n ${NETWORK}

#Delete NSG
az network nsg delete -g ${USER} -n ${NSG}

printf "\nSuccessfully completed clean-up process.\n"
