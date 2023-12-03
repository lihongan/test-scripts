#!/bin/bash

echo "Usage: clear-f5.sh [/partition/path]"
echo "  will clear default /Common partition if not specify one"

if [ $# -gt 1 ]; then
  echo 1>&2 "$0: too many arguments"
  exit 2
fi

if [ $# -eq 0 ]; then
  ssh admin@10.66.144.115 "
    tmsh show net fdb
    tmsh delete net fdb tunnel vxlan5000 static
    tmsh modify ltm virtual ose-vserver policies delete { openshift_insecure_routes }
    tmsh modify ltm virtual https-ose-vserver policies delete { openshift_secure_routes }
    tmsh delete ltm policy all
    tmsh delete ltm pool all
    tmsh delete ltm node all
    tmsh delete net self 10.130.0.1/14
    tmsh delete net tunnels tunnel vxlan5000
  "
elif [ $# -eq 1 ]; then
  ssh admin@10.66.144.115 "
    tmsh -c 'cd $1; show net fdb'
    tmsh -c 'cd $1; delete net fdb tunnel vxlan5000 static'
    tmsh -c 'cd $1; modify ltm virtual ocp-http-vserver policies delete { openshift_insecure_routes }'
    tmsh -c 'cd $1; modify ltm virtual ocp-https-vserver policies delete { openshift_secure_routes }'
    tmsh -c 'cd $1; delete ltm policy all'
    tmsh -c 'cd $1; delete ltm pool all'
    tmsh -c 'cd $1; delete ltm node all'
    tmsh -c 'cd $1; delete net self 10.130.0.1/14'
    tmsh -c 'cd $1; delete net tunnels tunnel vxlan5000'
  "
fi
