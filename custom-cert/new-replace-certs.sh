#!/bin/bash

apps_domain="$(oc get ingress.config/cluster -o jsonpath='{.spec.domain}')"

mkdir /tmp/replcert/

openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -keyout /tmp/replcert/ca.key -out /tmp/replcert/ca.crt -nodes -subj '/CN=test-root-ca'

openssl req -newkey rsa:4096 -nodes -sha256 -keyout /tmp/replcert/wildcard.key -out /tmp/replcert/wildcard.csr -subj "/CN=*.$apps_domain" 

openssl x509 -req -extfile <(printf "subjectAltName=DNS:*.$apps_domain") -days 365 -in /tmp/replcert/wildcard.csr -CA /tmp/replcert/ca.crt -CAcreateserial -CAkey /tmp/replcert/ca.key -out /tmp/replcert/wildcard.crt

# create secret for ingress and replace default ingress certs 
oc -n openshift-ingress create secret tls custom-certs-default --cert=/tmp/replcert/wildcard.crt --key=/tmp/replcert/wildcard.key
oc patch --type=merge --namespace openshift-ingress-operator ingresscontrollers/default \
  --patch '{"spec":{"defaultCertificate":{"name":"custom-certs-default"}}}'

# create configmap and replace trustedCA (custom PKI)
oc create configmap user-ca-bundle --from-file=ca-bundle.crt=/tmp/replcert/ca.crt -n openshift-config
oc patch proxy/cluster --patch '{"spec":{"trustedCA":{"name":"user-ca-bundle"}}}' --type=merge
