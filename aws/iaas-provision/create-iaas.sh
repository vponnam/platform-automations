#!/bin/bash

set -ue

# Create s3 buckets
#aws s3api create-bucket --bucket ${USER}-opsman --region us-east-1
#aws s3api create-bucket --bucket ${USER}-buildpacks --region us-east-1
#aws s3api create-bucket --bucket ${USER}-droplets --region us-east-1
#aws s3api create-bucket --bucket ${USER}-packages --region us-east-1
#aws s3api create-bucket --bucket ${USER}-resources --region us-east-1

# Create network
vpc_id=$(aws ec2 create-vpc --cidr-block 10.0.10.0/24 | jq -r .Vpc.VpcId)
aws ec2 create-tags --resources "$vpc_id" --tags Key=Name,Value="${USER}-vpc"
vault write concourse/main/${USER}/aws_vpc_id value=$vpc_id

# Create subnet
subnet_id=$(aws ec2 create-subnet --vpc-id $vpc_id  --availability-zone ${location}b --cidr-block 10.0.10.0/25 | jq -r .Subnet.SubnetId)
vault write concourse/main/${USER}/aws_public_subnet value=$subnet_id
aws ec2 create-tags --resources "$subnet_id" --tags Key=Name,Value="${USER}-public-subnet"

# Gateway
gateway=$(aws ec2 create-internet-gateway | jq -r .InternetGateway.InternetGatewayId)
vault write concourse/main/${USER}/aws_gw_id value=$gateway
aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $gateway
route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id | jq -r .RouteTable.RouteTableId)
aws ec2 create-route --route-table-id $route_table_id --destination-cidr-block 0.0.0.0/0 --gateway-id $gateway
aws ec2 associate-route-table  --subnet-id $subnet_id --route-table-id $route_table_id
vault write concourse/main/${USER}/aws_route_table value=$route_table_id

#Private subnet and Nat Gateway for outbound calls
private_subnet_id=$(aws ec2 create-subnet --vpc-id $vpc_id --availability-zone ${location}b --cidr-block 10.0.10.128/25 | jq -r .Subnet.SubnetId)
vault write concourse/main/${USER}/aws_private_subnet value=$private_subnet_id
aws ec2 create-tags --resources "$private_subnet_id" --tags Key=Name,Value="${USER}-private-subnet"
nat_eip=$(aws ec2 allocate-address --domain $vpc_id | jq -r .AllocationId)
vault write concourse/main/${USER}/aws_nat_eip value=$nat_eip
nat_gateway=$(aws ec2 create-nat-gateway --subnet-id $subnet_id --allocation-id $nat_eip | jq -r .NatGateway.NatGatewayId)
vault write concourse/main/${USER}/aws_nat_gateway value=$nat_gateway
until [[ $(aws ec2 describe-nat-gateways --nat-gateway-ids $nat_gateway | jq -r .NatGateways[].State) = "available" ]]
do
  sleep 30
done

priv_route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id | jq -r .RouteTable.RouteTableId)
vault write concourse/main/${USER}/aws_private_route_table value=$priv_route_table_id
aws ec2 create-route --route-table-id $priv_route_table_id --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $nat_gateway
aws ec2 associate-route-table  --subnet-id $private_subnet_id --route-table-id $priv_route_table_id

#NSG
om_nsg=$(aws ec2 create-security-group --group-name ${USER}-opsman-nsg --description "OpsMan Security Group" --vpc-id $vpc_id | jq -r .GroupId)
vault write concourse/main/${USER}/aws_om_nsg value=$om_nsg
aws ec2 authorize-security-group-ingress --group-id $om_nsg --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $om_nsg --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $om_nsg --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $om_nsg --protocol tcp --port 6868 --cidr 10.0.10.128/25
aws ec2 authorize-security-group-ingress --group-id $om_nsg --protocol tcp --port 25555 --cidr 10.0.10.128/25

pas_internal_nsg=$(aws ec2 create-security-group --group-name ${USER}-pas-internal-nsg --description "Internal VMs Security Group" --vpc-id $vpc_id | jq -r .GroupId)
aws ec2 authorize-security-group-ingress --group-id $pas_internal_nsg --protocol tcp --port 0-65535 --cidr 10.0.10.0/24
vault write concourse/main/${USER}/aws_pas_internal_nsg value=$pas_internal_nsg
pas_elb_nsg=$(aws ec2 create-security-group --group-name ${USER}-pas-elb-nsg --description "Web ELB Security Group" --vpc-id $vpc_id | jq -r .GroupId)
aws ec2 authorize-security-group-ingress --group-id $pas_elb_nsg --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $pas_elb_nsg --protocol tcp --port 4443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $pas_elb_nsg --protocol tcp --port 2222 --cidr 0.0.0.0/0
vault write concourse/main/${USER}/aws_web_elb_nsg value=$pas_elb_nsg

#create pas-web-elb
aws elb create-load-balancer --load-balancer-name pas-web-elb --listeners "Protocol=TCP,LoadBalancerPort=443,InstanceProtocol=TCP,InstancePort=443" --subnets $subnet_id --security-groups $pas_elb_nsg
vault write concourse/main/${USER}/aws_web_elb value=pas-web-elb

#create om_vm
opsman_vm=$(aws ec2 run-instances --instance-type t2.medium --image-id $om_ami_id --key-name $ssh_key_name --security-group-ids $om_nsg --subnet-id $subnet_id --associate-public-ip-address --block-device-mappings DeviceName=/dev/xvda,Ebs={VolumeSize=100} | jq -r .Instances[].InstanceId)
vault write concourse/main/${USER}/aws_om_id value=$opsman_vm
aws ec2 create-tags --resources $opsman_vm --tags Key=Name,Value=${USER}-OpsManVM

until [[ $(aws ec2 describe-instances --instance-ids $opsman_vm | jq -r .Reservations[].Instances[].State.Name) = "running" ]]
do
  sleep 15
done

OM_IP=$(aws ec2 describe-instances --instance-ids $opsman_vm | jq -r .Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp)
printf "\n${USER}-OpsManVM can be accessed with IP: $OM_IP\n"
