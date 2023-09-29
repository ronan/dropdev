#!/bin/bash
set -e

cd /workspace

echo "Initializing D9->D10 Migration Tool."
echo "🗑️  Deleting logs, databases and temporary files ..."
rm -rf data
mkdir -p data/logs data/db data/files data/tmp

echo "🗃️  Recreating databases ..."
 mariadb -h db --password=root -e 'DROP DATABASE IF EXISTS drupal9; CREATE DATABASE drupal9'
 mariadb -h db --password=root -e 'DROP DATABASE IF EXISTS drupal10; CREATE DATABASE drupal10'

if [ -f /workspace/inbox/*sql ]
then
    echo "🚚 Importing SQL dump ..."
    cat /workspace/inbox/*sql | mariadb -h db -u root -proot drupal9
fi
if [ -f /workspace/inbox/*sql.gz ]
then
    echo "📦 Importing gzipped SQL dump ..."
    zcat /workspace/inbox/*sql.gz | mariadb -h db -u root -proot drupal9
fi

if [ -f /workspace/inbox/*code.tar* ]
then
    echo "📚 Importing a Backup ..."
    echo "🛑 J/k this isn't done yet."
    exit -1
else
    for v in 9 10; do
        echo "💧 Composing a fresh copy of Drupal $v ..."

        rm -rf "drupal$v"
        mkdir -p "drupal$v"
        
        cd "drupal$v"
        rm -f ./composer.lock
        [ -f "/workspace/src/drupal$v/composer.json" ] && ln -fs /workspace/src/composer.json ./composer.json
        [ -f "/workspace/src/drupal$v/composer.lock" ] && ln -fs /workspace/src/composer.lock ./composer.lock
        if [ ! -f "composer.json" ] 
        then
            yes | composer create-project "drupal/recommended-project:^$v" ./
        fi
        yes | composer require drush/drush  --ignore-platform-req=php
        composer install --no-interaction --ignore-platform-req=php

        cd /workspace
    done
fi

# echo "📁 Adding custom code directories ..."
# dirs=( "modules" "themes" "sites" "layouts" )
# for dir in "${dirs[@]}"
# do
#     if [ ! -f "/workspace/src/$dir" ]
#     then
#         cp -rf "/workspace/backdrop/$dir" "/workspace/src/"
#     fi
#     rm -rf "/workspace/backdrop/$dir"
#     ln -fs "/workspace/src/$dir" "/workspace/backdrop/$dir"
#     chmod -R a+w "/workspace/src/$dir"
# done

echo "📝 Adding local settings ..."
cp -f /workspace/.devcontainer/drupal9/settings.local.php /workspace/drupal9/settings.local.php
cp -f /workspace/.devcontainer/drupal10/settings.local.php /workspace/drupal10/settings.local.php

echo "🗳️  Installing Drupal 9 ..."
drush9 si --db-url=mysql://root:root@db/drupal9 --site-name="D9 Site" -y

echo "🗳️  Installing Drupal 10 ..."
drush10 si --db-url=mysql://root:root@db/drupal10 --site-name="D10 Site" -y

echo "👇 Drupal 9 site login"
drush9 uli
echo "👇 Drupal 10 site login"
drush10 uli

echo "🎉 🎉 🎉"
