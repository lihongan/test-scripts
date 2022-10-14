#!/bin/bash

# IFS=${`\n`}

create_mtls_certs()
{
  tmp_dir=$1
  cd $tmp_dir

  # generate rootCA
  openssl genrsa -out ca.key 2048
  openssl req -x509 -new -nodes -key ca.key -days 2 -out ca.pem -subj "/CN=ne_mtls_ca"

  # download example openssl.conf and update if required
  curl -O -sS https://raw.githubusercontent.com/lihongan/test-scripts/master/openssl/example.conf
  cp example.conf openssl.conf

  # use the updated openssl.conf to generate client certificate
  openssl genrsa -out client.key 2048
  openssl req -new -config openssl.conf -key client.key -out client.csr
  openssl x509 -req -CA ca.pem -CAkey ca.key -CAcreateserial -extfile openssl.conf -extensions v3_req -in client.csr -out client.crt -days 1
  openssl x509 -text -noout -in client.crt | grep "Alternative Name" -A 1

  cd -
}

tmp_dir=$(mktemp -d -t rpl-certs-$(date +%Y%m%d-%H%M%S)-XXX)
echo "Created tmp folder $tmp_dir"

create_mtls_certs $tmp_dir
