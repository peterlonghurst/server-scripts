#!/bin/bash

# Checks to see if the external IP address has changed, and if so writes the new address
# to a file which is then pulic key encrypted (using Gnu Privacy Guard) and uploaded
# to a git repository. This secret is written to a directory called "secrets" which is
# a sibbling to the directory where this script lives.
# 
# Script takes one argument; the email address of the GPG recipient. This script requires
# the public key for this recipient to be installed and trusted on the system.
#
# Usage: hasExternalIPChanged.sh gpg.recipient@address
#


recipient=$1

ROOTDIR=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/..`


$ROOTDIR/scripts/hasExternalIPChanged.sh

if [ $? -eq 0 ]
then
    echo "Nothing to do!"
    exit
fi

currentIP=`external-ip`
filename=`hostname`ExternalIP

echo "Encrypting secret:" $filename
`echo $currentIP > /tmp/$filename`
gpg --yes --output $ROOTDIR/secrets/$filename.gpg --encrypt --recipient $recipient /tmp/$filename

echo "Push secret up to github"
git --git-dir=$ROOTDIR/.git --work-tree=$ROOTDIR add secrets/$filename.gpg
git --git-dir=$ROOTDIR/.git commit -m "Script commit of secret $filename"
git --git-dir=$ROOTDIR/.git push
