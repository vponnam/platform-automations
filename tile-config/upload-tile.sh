#!/bin/bash

set -ue


bosh int <(echo "${OM_ENV}") > env.yml

om --env env.yml upload-product -p pas/cf-*.pivotal
