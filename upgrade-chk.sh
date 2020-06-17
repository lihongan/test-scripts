#!/bin/bash

ROUTE_CONSOLE=$(oc get route console -n openshift-console -o json | jq '.spec.host' --raw-output)
ROUTE_AUTH=$(oc get route oauth-openshift -n openshift-authentication -o json | jq '.spec.host' --raw-output)
echo "Checking console/auth route..."
echo "--->$ROUTE_CONSOLE"
echo "--->$ROUTE_AUTH"

for i in {1..10000}
do
    echo "$(date)"
    STATUS=$(curl -m 5 -sS -o /dev/null -w "%{http_code}" https://$ROUTE_CONSOLE -k)
    echo "$STATUS"
    if [ $STATUS -ne 200 ]; then
        echo "$(tput setaf 1)Warning...$STATUS $(tput sgr 0)"
    fi
    sleep 1
    
    STATUS=$(curl -m 5 -sS -o /dev/null -w "%{http_code}" https://$ROUTE_AUTH -k)
    echo "$STATUS"
    if [ $STATUS -ne 403 ]; then
        echo "$(tput setaf 1)Warning...$STATUS $(tput sgr 0)"
    fi
    sleep 1
done
