#!/bin/bash

set -ue


bosh int <(echo "${OM_ENV}") > env.yml

om --env env.yml uplaod-product -p pas/cf-*.pivotal
