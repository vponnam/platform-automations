#!/bin/bash

set -uo pipefail

# Remove buckets
#aws s3 rb s3://bucket-name --force 

aws ec2 delete-nat-gateway --nat-gateway-id $nat_gw
until [[ $(aws ec2 describe-nat-gateways --nat-gateway-ids $nat_gw | jq -r .NatGateways[].State) = "" || $(aws ec2 describe-nat-gateways --nat-gateway-ids $nat_gw | jq -r .NatGateways[].State) = "deleted" ]]
do
  sleep 10
done

#Delete PAS Web ELB
aws elb delete-load-balancer --load-balancer-name $pas_web_elb

#Delete OM
until [[ $(aws ec2 terminate-instances --instance-ids $om_id | jq -r .TerminatingInstances[].CurrentState.Name) = "terminated" ]]
do
  sleep 20
done

sleep 30
#Delete NSGs
aws ec2 delete-security-group --group-id $om_nsg
aws ec2 delete-security-group --group-id $pas_internal_nsg
aws ec2 delete-security-group --group-id $pas_web_nsg

#Delete subnets
for retry in {1..3}; do
 if aws ec2 delete-subnet --subnet-id $pub_subnet
 then
    aws ec2 delete-subnet --subnet-id $priv_subnet
    break
 fi
 sleep 30
done

aws ec2 detach-internet-gateway --internet-gateway-id $gw_id --vpc-id $vpc_id
aws ec2 delete-internet-gateway --internet-gateway-id $gw_id

aws ec2 delete-route-table --route-table-id $rt_id1
aws ec2 delete-route-table --route-table-id $rt_id2

aws ec2 delete-vpc --vpc-id $vpc_id
aws ec2 release-address --allocation-id $eip
