## Two Clients for OCPBUGS-43745 Investigation
see https://issues.redhat.com/browse/OCPBUGS-43745

### Golang Http Client
```console
$ go run simul_eag.go
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
