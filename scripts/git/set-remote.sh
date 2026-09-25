#!/bin/bash -evx

url1=$(git remote -v | grep fetch | awk '$1=="origin" {print $2}')
url2=$(echo $url1 | sed "s/token:.*@//" | sed "s|https://|ssh://git@|")

echo "url1 = $url1"
echo "url2 = $url2"

if [[ $url1 =~ ^https ]]
then
  git remote rename origin origin1
  git remote add origin $url2
  git remote remove origin1
fi

git pull origin dev
git push --set-upstream origin dev
git remote -v
