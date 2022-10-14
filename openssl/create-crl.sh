### Parsing A CRL 
# Most CRLs are DER encoded, but you can use -inform PEM if your CRL is not binary. 
# If you’re unsure if it is DER or PEM open it with a text editor. 
# If you see —–BEGIN X509 CRL—– then it’s PEM  
# if you see strange binary-looking garbage characters it’s DER.

openssl crl -inform DER -in mycrl.crl -text -noout

### example output
Certificate Revocation List (CRL):
        Version 2 (0x1)
        Signature Algorithm: sha1WithRSAEncryption
        Issuer: C = GB, ST = Greater Manchester, L = Salford, O = COMODO CA Limited, CN = COMODO Certification Authority
        Last Update: Aug 25 19:02:13 2021 GMT
        Next Update: Sep  1 19:02:13 2021 GMT
        CRL extensions:
            X509v3 Authority Key Identifier: 
                keyid:0B:58:E5:8B:C6:4C:15:37:A4:40:A9:30:A9:21:BE:47:36:5A:56:FF

            X509v3 CRL Number: 
                3798

### using faketime to generate short lifetime less than one hour, in below case 10 min to be expired after creating the crl
faketime '50 minutes ago' openssl ca -gencrl -crlhours 1 -out root.crl -config root-ca.cnf
