#!/bin/bash

ExternalIPFile=/var/tmp/external-ip

currentIP=`external-ip`

if [ -f "$ExternalIPFile" ]
then
    lastIP=`cat $ExternalIPFile`
    if [ $currentIP == $lastIP ]
    then
       echo "External IP address unchanged:" $currentIP
       exit 0
    fi
else
    lastIP=0.0.0.0
fi

echo "New external IP address..."
echo "Last    IP address:" $lastIP
echo "Current IP address:" $currentIP

`echo $currentIP > $ExternalIPFile`
exit 1
