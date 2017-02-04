#!/bin/bash

recipient=pete.longhurst@gmail.com

ROOTDIR=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/..`

echo $ROOTDIR

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
