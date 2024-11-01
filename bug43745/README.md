## Two Clients for OCPBUGS-43745 Investigation
see https://issues.redhat.com/browse/OCPBUGS-43745

### Golang Http Client
```console
$ go run simul_eap.go
```

### Java Apache HTTP Client (simplify from EAP test code)

download HttpComponets lib from https://hc.apache.org/downloads.cgi
```console
$ mkdir java
$ cd java
$ tar -zxf  httpcomponents-client-4.5.14-bin.tar.gz
$ javac -cp '.:./lib/*' SimulEapTest.java
$ java -cp '.:./lib/*' SimulEapTest
```

### Example Output with Golang Http Client
```console
$ go run simul_eap.go 
2024/11/01 17:55:46 Response Body: Hello-OpenShift web-server-rc2-kk49m http-8080

>>> please update the route, waiting 240s and try again
2024/11/01 17:59:46 Response Body: Hello-OpenShift web-server-rc2-kk49m http-8080      <<<--- expecting backend of updated service but still got old one

>>> waiting 6s and try again
2024/11/01 17:59:52 Response Body: Hello-OpenShift web-server-rc-lgnb6 http-8080

>>> waiting 6s and try again
2024/11/01 17:59:59 Response Body: Hello-OpenShift web-server-rc-lgnb6 http-8080

```
