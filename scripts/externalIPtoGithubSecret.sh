#!/bin/bash

recipient=pete.longhurst@gmail.com

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

$DIR/hasExternalIPChanged.sh

if [ $? -eq 0 ]
then
    echo "Nothing to do!"
    exit
fi

currentIP=`external-ip`
filename=`hostname`ExternalIP

echo "Encrypting secret:" $filename
`echo $currentIP > /tmp/$filename`
gpg --yes --output $DIR/../secrets/$filename.gpg --encrypt --recipient $recipient /tmp/$filename

echo "Push secret up to github"
git --git-dir=$DIR/../.git --work-tree=$DIR/../secrets add $filename.gpg
git --git-dir=$DIR/../.git commit -m "Script commit of secret $filename"
git --git-dir=$DIR/../.git push
