#!/bin/bash

# IFS=${`\n`}

create_mtls_certs()
{
  tmp_dir=$1
  cd $tmp_dir

  # download example openssl.cnf and update if required
  curl -O -sS https://raw.githubusercontent.com/lihongan/test-scripts/master/mtls/example.cnf
  cp example.cnf openssl.cnf

  touch index.txt
  echo 01 > serial
  echo 1000 > crlnumber

  echo "---> generate rootCA..."
  # req for CSR, x509 for certificate
  openssl genrsa -out ca.key 2048
  openssl req -new -key ca.key -out ca.csr -subj "/CN=ne_mtls_ca"
  openssl x509 -req -in ca.csr -out ca.crt -days 1 -signkey ca.key -extfile openssl.cnf -extensions v3_ca
  # check certificate
  openssl x509 -text -noout -in ca.crt | grep "X509v3" -A 1

  echo "---> generate client certificate..."
  openssl genrsa -out client.key 2048
  openssl req -new -config openssl.cnf -key client.key -out client.csr
  openssl ca -batch -config openssl.cnf -extensions v3_req -days 1 -out client.crt -infiles client.csr
  #check certificate
  openssl x509 -text -noout -in client.crt | grep "Alternative Name" -A 1

  echo "---> generate crl..."
  # openssl ca -revoke crt
  # openssl ca -gencrl -out crl
  faketime '50 minutes ago' openssl ca -gencrl -crlhours 1 -keyfile ca.key -cert ca.crt -out root.crl.pem -config openssl.cnf
  mkdir crl
  openssl crl -inform PEM -in root.crl.pem -outform DER -out crl/root.crl

  cd -
}

tmp_dir=$(mktemp -d -t mtls-$(date +%Y%m%d-%H%M%S)-XXX)
echo "Created tmp folder $tmp_dir"

create_mtls_certs $tmp_dir
