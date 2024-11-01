## Two Clients used to investegate BUG https://issues.redhat.com/browse/OCPBUGS-43745

### Goland Client
```console
$ go run simul_eag.go
```

### Java Apache HTTP Client (simple copy from EAP test code)

download HttpComponets lib from https://hc.apache.org/downloads.cgi
```console
$ mkdir java
$ cd java
$ tar -zxf  httpcomponents-client-4.5.14-bin.tar.gz
$ javac -cp '.:./lib/*' SimulEapTest.java
$ java -cp '.:./lib/*' SimulEapTest
```
