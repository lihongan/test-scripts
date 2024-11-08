## Configuration Steps
Tested with 4.18 

### Enable feature gate
```console
$ oc patch featuregates/cluster --type=merge --patch='{"spec":{"featureSet":"CustomNoUpgrade","customNoUpgrade":{"enabled":["GatewayAPI"]}}}'

## ensure gateway CRDs are created
$ oc get crds | grep -e gateway.networking.k8s.io -e maistra.io
```
note: all nodes will be restarted, wait for some time until router pods are recreated.

### Create GatewayClass

```console
$ oc create -f -<<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: GatewayClass
metadata:
  name: openshift-default
spec:
  controllerName: openshift.io/gateway-controller
EOF

// ensure OSSM/istio operatir is installed as well
$ oc get gatewayclass
$ oc -n openshift-operators get sub,csv,pod
$ oc -n openshift-ingress get pod
```

### Create Gateway
```console
// to support https in gateway we need prepare the secret
base_domain="$(oc get dnses.config/cluster -o jsonpath='{.spec.baseDomain}')"
gwapi_domain="gwapi.${base_domain}"
mkdir /tmp/gwapi
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -keyout /tmp/gwapi/ca.key -out /tmp/gwapi/ca.crt -nodes -subj '/C=US/ST=NC/L=Chocowinity/O=OS3/OU=Eng/CN=gwapi-ca' && openssl req -newkey rsa:4096 -nodes -sha256 -keyout /tmp/gwapi/wildcard.key -out /tmp/gwapi/wildcard.csr -subj "/C=US/ST=NC/L=Chocowinity/O=OS3/OU=Eng/CN=*.$gwapi_domain" && openssl x509 -req -days 365 -in /tmp/gwapi/wildcard.csr -CA /tmp/gwapi/ca.crt -CAcreateserial -CAkey /tmp/gwapi/ca.key -out /tmp/gwapi/wildcard.crt
oc -n openshift-ingress create secret tls gwapi-wildcard --cert=/tmp/gwapi/wildcard.crt --key=/tmp/gwapi/wildcard.key

$ oc create -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: gateway
  namespace: openshift-ingress
spec:
  gatewayClassName: openshift-default
  listeners:
  - name: http
    hostname: "*.$gwapi_domain"
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    hostname: "*.$gwapi_domain"
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
      - name: gwapi-wildcard
    allowedRoutes:
      namespaces:
        from: All
EOF

// ensure gateway pod ans LB service are created
$ oc -n openshift-ingress get svc,pod

```

### Create Application pod,service and HTTPRoute

```console
$ oc new-project gwapi-test
$ oc create -f testdata/web-server-rc.yaml

$ oc create -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: myroute
spec:
  parentRefs:
  - name: gateway
    namespace: openshift-ingress
  hostnames: ["test.$gwapi_domain"]
  rules:
  - backendRefs:
    - name: service-unsecure
      port: 27017
EOF

```

### Curl the HTTPRoute
```console
$ oc get httproute
$ curl http://test.$gwapi_domain/
$ curl --cacert /tmp/gwapi/ca.crt "https://test.$gwapi_domain/" -v

```
note: HTTP2 is enabled by default in envoy proxy
