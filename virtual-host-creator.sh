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
	echo "<VirtualHost *:80>
		ServerAdmin webmaster@localhost
		ServerName $domain_name
		ServerAlias www.$domain_name
		DocumentRoot /var/www/$domain_name/public_html
		ErrorLog /var/www/$domain_name/logs/error.log
		CustomLog /var/www/$domain_name/logs/access.log combined
	</VirtualHost>" >> vhc-includes/virtual-host.conf

	sudo cp vhc-includes/virtual-host.conf /etc/apache2/sites-available/$domain_name.conf
	
	#enable site
	sudo a2ensite $domain_name

else
	echo -n "Create the New Virtual Host File \n"
	echo "Listen $localsiteport
	<VirtualHost *:$localsiteport>
		ServerAdmin webmaster@localhost
		ServerName $domain_name
		ServerAlias www.$domain_name
		DocumentRoot /var/www/$domain_name/public_html
		ErrorLog /var/www/$domain_name/logs/error.log
		CustomLog /var/www/$domain_name/logs/access.log combined
	</VirtualHost>" >> vhc-includes/virtual-host.conf
	sudo cp vhc-includes/virtual-host.conf /etc/apache2/sites-available/$domain_name:$localsiteport.conf
	sudo a2ensite $domain_name:$localsiteport
fi


#TODO Activate site sudo a2ensite example.com