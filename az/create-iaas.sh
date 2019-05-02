#!/bin/bash

set -ue

az login --service-principal -u $app_id -p $client_secret -t $tenant

#Create user resource group
if [[ $(az group exists -n ${USER}) = true ]]
then
  printf "Resource group already exists.\n"
else
  az group create -l ${LOCATION} -n ${USER}
fi
#Create NSG
az network nsg create --name ${NSG_NAME} \
--resource-group ${USER} \
--location ${LOCATION}

# NSG rules
az network nsg rule create --name ssh \
--nsg-name ${NSG_NAME} --resource-group ${USER} \
--protocol Tcp --priority 100 \
--destination-port-ranges '22'

az network nsg rule create --name http \
--nsg-name ${NSG_NAME} --resource-group ${USER} \
--protocol Tcp --priority 200 \
--destination-port-ranges '80'

az network nsg rule create --name https \
--nsg-name ${NSG_NAME} --resource-group ${USER} \
--protocol Tcp --priority 300 \
--destination-port-ranges '443'

az network nsg rule create --name diego-ssh \
--nsg-name ${NSG_NAME} --resource-group ${USER} \
--protocol Tcp --priority 400 \
--destination-port-ranges '2222'

az network vnet create --name ${NETWORK} \
--resource-group ${USER} --location ${LOCATION} \
--address-prefixes 10.0.0.0/24

az network vnet subnet create --name ${SUBNET} \
--vnet-name ${NETWORK} \
--resource-group ${USER} \
--address-prefix 10.0.0.0/25 \
--network-security-group ${NSG_NAME}

az storage account create --name ${USER}storageaccount \
--resource-group ${USER} \
--sku Standard_LRS \
--location ${LOCATION}

CONNECTION_STRING=$(az storage account show-connection-string --name ${USER}storageaccount --resource-group ${USER} | jq .connectionString)

az storage container create --name opsmanager \
--connection-string ${CONNECTION_STRING}

az storage container create --name bosh \
--connection-string ${CONNECTION_STRING}

az storage container create --name stemcell --public-access blob \
--connection-string ${CONNECTION_STRING}

az storage table create --name stemcells \
--connection-string ${CONNECTION_STRING}

opsmanIP=$(az network public-ip create --name ${OM_IP} --resource-group ${USER} --location ${LOCATION} --allocation-method Static | jq -r .publicIp.ipAddress)

az network nic create --vnet-name ${NETWORK} \
--subnet ${SUBNET} --network-security-group ${NSG_NAME} \
--private-ip-address 10.0.0.10 \
--public-ip-address ${OM_IP} \
--resource-group ${USER} \
--name opsman-nic --location ${LOCATION}

#Image upload handling when using Managed disks
if [[ $(az storage blob show --name opsman-${OM_VERSION}.vhd --container-name opsmanager --connection-string ${CONNECTION_STRING} | jq -r .name) = "opsman-${OM_VERSION}.vhd" ]] 
then
  printf "\nopsman-${OM_VERSION}.vhd previously uploaded to blobstore\n"
else  
az storage blob copy start --source-uri ${OPS_MAN_IMAGE_URL} \
--connection-string ${CONNECTION_STRING} \
--destination-container opsmanager \
--destination-blob opsman-${OM_VERSION}.vhd
printf "\nUploading OpsMan image to opsmanager container..\n"
sleep 180

until [[ $(az storage blob show --name opsman-${OM_VERSION}.vhd --container-name opsmanager --connection-string ${CONNECTION_STRING} | jq -r .properties.copy.status) = "success" ]]
do
  sleep 30
done
fi

#safe sleep for status change delay
sleep 15

az image create --resource-group ${USER} \
--name opsman-image-${OM_VERSION} \
--source https://${USER}storageaccount.blob.core.windows.net/opsmanager/opsman-${OM_VERSION}.vhd \
--location ${LOCATION} \
--os-type Linux

#Launch the Opsman VM
az vm create --name opsman-${OM_VERSION} --resource-group ${USER} \
 --location ${LOCATION} \
 --nics ${OM_NIC} \
 --image opsman-image-${OM_VERSION} \
 --os-disk-size-gb 100 \
 --os-disk-name ${OM_DISK} \
 --admin-username ubuntu \
 --size Standard_DS2_v2 \
 --storage-sku Standard_LRS \
 --ssh-key-value ${SSH_KEY_PATH}

echo "OpsManager VM can be access by using this IP: ${opsmanIP}" 

PAS_Domain_IP=$(az network public-ip create --name pas-domains-ip --resource-group ${USER} --location ${LOCATION} --allocation-method Static | jq -r .publicIp.ipAddress)

echo "IP for PAS wildcard domains: *.${PAS_Domain_IP}.xip.io"
