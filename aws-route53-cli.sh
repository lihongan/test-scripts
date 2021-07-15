
## find all NS type records
aws route53 list-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --query "ResourceRecordSets[?Type == 'NS']" | jq '.[].Name'

## find all hosted zones
aws route53 list-hosted-zones | jq '.HostedZones[].Name'

