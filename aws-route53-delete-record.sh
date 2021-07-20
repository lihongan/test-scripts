#!/bin/bash
set -x

HOSTED_ZONE_ID=XXXX
prefix='{"Comment": "Delete single record set","Changes":[{"Action": "DELETE","ResourceRecordSet":'
suffix='}]}'

cat tobedeleted.txt | while read line
do
    echo $line
    jsonfile=$prefix$(aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --query "ResourceRecordSets[?Name == $line]" | jq -c '.[]')$suffix
    echo $jsonfile > onerecord.tmp
    aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch file://onerecord.tmp
done

##### example of tobedeleted.txt
##### 'api.test1.example.com'
##### 'api.test2.example.com'

