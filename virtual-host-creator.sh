#!/bin/bash

#syntax  

domain_name=$1
if [ ${#domain_name} -eq 0 ]; then
	echo "Please give a domain name as an argument"
	exit 1
fi

localsiteport=$2

deploy_dir=/var/www/$domain_name/public_html

if [ ${#localsite} -eq 0 ]; then
	echo -n "Creating www dir \n"
	sudo mkdir -p $deploy_dir

	echo -n "Setting permissions \n"
	sudo chown -R $USER:$USER $deploy_dir

	sudo chmod -R 755 /var/www

	echo -n "Copying index.html file \n"
	sudo cp vhc-includes/index.html $deploy_dir
	echo -n "Create the New Virtual Host File \n"
	sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/$domain_name
	echo -n "Please edit the new virtual file at /etc/apache2/sites-available/$domain_name \n"
else
	echo -n "Create the New Virtual Host File \n"
	sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/$domain_name-$localsiteport
	echo -n "Please edit the new virtual file at /etc/apache2/sites-available/$domain_name-$localsiteport \n"
fi


#TODO Activate sitesudo a2ensite example.com