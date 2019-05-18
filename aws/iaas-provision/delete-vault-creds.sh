#!/bin/bash

set -uo pipefail

vault delete concourse/main/${USER}/aws_vpc_id
vault delete concourse/main/${USER}/aws_public_subnet
vault delete concourse/main/${USER}/aws_gw_id
vault delete concourse/main/${USER}/aws_route_table
vault delete concourse/main/${USER}/aws_private_subnet
vault delete concourse/main/${USER}/aws_nat_eip
vault delete concourse/main/${USER}/aws_nat_gateway
vault delete concourse/main/${USER}/aws_private_route_table
vault delete concourse/main/${USER}/aws_om_nsg
vault delete concourse/main/${USER}/aws_pas_internal_nsg
vault delete concourse/main/${USER}/aws_web_elb_nsg
vault delete concourse/main/${USER}/aws_web_elb
vault delete concourse/main/${USER}/aws_om_id
