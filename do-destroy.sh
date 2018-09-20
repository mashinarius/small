#!/bin/bash
export DO_TOKEN=

terraform destroy \
  -var "do_token=${DO_TOKEN}" \
  -var "pub_key=$HOME/.ssh/id_rsa.pub" \
  -var "pvt_key=$HOME/.ssh/id_rsa" \
  -var "ssh_fingerprint="