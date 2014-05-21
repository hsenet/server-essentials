#!/bin/bash

sudo apt-get install lamp-server^

echo -n "Add your user to the www-data group"
sudo usermod -a -G www-data $USER

echo -n "Add the /var/www folder to the www-data group"
sudo chgrp -R www-data /var/www

echo -n "Give write permissions to the www-data group"
sudo chmod -R g+w /var/www

echo -n "Enable virtual Hosts"
sudo a2enmod vhost_alias