#!/bin/bash

# IFS=${`\n`}


create_apps_certs()
{
  tmp_dir=$1
  domain=$2
  cd $tmp_dir

  # download required files
  curl -O -sS https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/ca.key
  curl -O -sS https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/ca.pem
  curl -O -sS https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/openssl.conf

  # replace DNS.1 with current domain
  sed -i.bak "s/example.com/${domain}/g" openssl.conf

  openssl genrsa -out apps.key 2048
  openssl req -new -config openssl.conf -key apps.key -out apps.csr
  openssl x509 -req -CA ca.pem -CAkey ca.key -CAcreateserial -extfile openssl.conf -extensions v3_req -in apps.csr -out apps.crt -days 3650
  openssl x509 -text -noout -in apps.crt | grep "Alternative Name" -A 1

  cd -
}


domain="$(oc get ingress.config cluster -o jsonpath='{.spec.domain}')"
echo "Your ingress subdomain is: $domain"

tmp_dir=$(mktemp -d -t rpl-certs-$(date +%Y%m%d-%H%M%S)-XXX)
echo "Created tmp folder $tmp_dir"

create_apps_certs $tmp_dir $domain

# create secret for ingress and replace default ingress certs 
oc --namespace openshift-ingress create secret tls custom-certs-default --cert=$tmp_dir/apps.crt --key=$tmp_dir/apps.key
oc patch --type=merge --namespace openshift-ingress-operator ingresscontrollers/default \
  --patch '{"spec":{"defaultCertificate":{"name":"custom-certs-default"}}}'

# create configmap and replace trustedCA (custom PKI)
oc create configmap user-ca-bundle --from-file=ca-bundle.crt=$tmp_dir/ca.pem -n openshift-config
oc patch proxy/cluster --patch '{"spec":{"trustedCA":{"name":"user-ca-bundle"}}}' --type=merge

rm -rf $tmp_dir
