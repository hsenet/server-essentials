#!/bin/bash

#syntax  

domain_name=$1
if [ ${#domain_name} -eq 0 ]; then
	echo "Please give a domain name as an argument"
	exit 1
fi

localsiteport=$2

deploy_dir=/var/www/$domain_name/public_html
log_dir=/var/www/$domain_name/logs

if [ ${#localsiteport} -eq 0 ]; then
	echo -n "Creating www dir \n"
	sudo mkdir -p $deploy_dir
	sudo mkdir -p $log_dir
	echo -n "Setting permissions \n"
	sudo chown -R $USER:$USER $deploy_dir

	sudo chmod -R 755 /var/www

	echo -n "Copying index.html file \n"
	sudo cp vhc-includes/index.html $deploy_dir
	echo -n "Create the New Virtual Host File \n"
	sudo cp vhc-includes/virtual-host.conf /etc/apache2/sites-available/$domain_name.conf
	echo -n "Activating the new site \n"
	sudo ln -s ../sites-available/$domain_name /etc/apache2/sites-enabled/111-80-$domain_name.conf
	echo -n "Please edit the new virtual file at /etc/apache2/sites-available/$domain_name \n"

else
	echo -n "Create the New Virtual Host File \n"
	sudo cp vhc-includes/virtual-host.conf /etc/apache2/sites-available/$domain_name-$localsiteport.conf

	echo -n "Activating the new site at $domain_name:$localsiteport \n"
	sudo ln -s ../sites-available/$domain_name-$localsiteport /etc/apache2/sites-enabled/111-$localsiteport-$domain_name.conf

	echo -n "Please edit the new virtual file at /etc/apache2/sites-available/$domain_name-$localsiteport \n"
fi


#TODO Activate site sudo a2ensite example.com