## Configurations and Test Steps

Tested with OCP 4.19/4.20

Note: The feature has been promoted to GA since 4.19.

Supported Platforms: AWS, Azure, GCP, IBMCloud, PowerVS

Supported Arch: amd64, arm64, ppc64le

### Create GatewayClass

note: OSSM operator will be installed automatically after creating gatewayclass

```console
$ oc create -f -<<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-default
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF

// wait and ensure gatewayclass ACCEPTED=True
$ oc get gatewayclass
NAME                CONTROLLER                           ACCEPTED   AGE
openshift-default   openshift.io/gateway-controller/v1   True       106s

// ensure OSSM operator is installed
$ oc -n openshift-operators get sub,csv,pod

// ensure istio STATUS=Healthy
$ oc get istio 
NAME                REVISIONS   READY   IN USE   ACTIVE REVISION     STATUS    VERSION   AGE
openshift-gateway   1           1       0        openshift-gateway   Healthy   v1.24.3   5m16s

// ensure istiod deployment is ready
$ oc -n openshift-ingress get deployment
NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
istiod-openshift-gateway   1/1     1            1           6m46s

```

### Create Gateway
```console
$ base_domain="$(oc get dnses.config/cluster -o jsonpath='{.spec.baseDomain}')"
$ gwapi_domain="gwapi.${base_domain}"

$ oc create -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
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
EOF

// ensure gateway pod and LB service are created
$ oc -n openshift-ingress get svc,pod
$ oc -n openshift-ingress get gateway

```

### Create Application pod,service and HTTPRoute

```console
$ oc new-project gwapi-test
$ oc create -f https://raw.githubusercontent.com/lihongan/test-scripts/refs/heads/master/GatewayAPI/web-server-deploy.yaml

$ oc create -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
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

## useful links:

https://github.com/kubernetes-sigs/gateway-api

https://gateway-api.sigs.k8s.io/

https://github.com/openshift-service-mesh

###
### （Alternative) Create Gateway with HTTPS
```console
// to support https in gateway we need prepare the secret
$ base_domain="$(oc get dnses.config/cluster -o jsonpath='{.spec.baseDomain}')"
$ gwapi_domain="gwapi.${base_domain}"
$ mkdir /tmp/gwapi
$ openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -keyout /tmp/gwapi/ca.key -out /tmp/gwapi/ca.crt -nodes -subj '/C=US/ST=NC/L=Chocowinity/O=OS3/OU=Eng/CN=gwapi-ca' && openssl req -newkey rsa:4096 -nodes -sha256 -keyout /tmp/gwapi/wildcard.key -out /tmp/gwapi/wildcard.csr -subj "/C=US/ST=NC/L=Chocowinity/O=OS3/OU=Eng/CN=*.$gwapi_domain" && openssl x509 -req -days 365 -in /tmp/gwapi/wildcard.csr -CA /tmp/gwapi/ca.crt -CAcreateserial -CAkey /tmp/gwapi/ca.key -out /tmp/gwapi/wildcard.crt
$ oc -n openshift-ingress create secret tls gwapi-wildcard --cert=/tmp/gwapi/wildcard.crt --key=/tmp/gwapi/wildcard.key

$ oc create -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
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

// ensure gateway pod and LB service are created
$ oc -n openshift-ingress get svc,pod
$ oc -n openshift-ingress get gateway

```
