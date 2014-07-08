#!/bin/bash

#syntax  

read -p "Enter Your Domain Name: " domain_name

if [ ${#domain_name} -eq 0 ]; then
	echo "Please give a domain name as an argument"
	exit 1
fi

read -p "Enter a site port or press enter: " localsiteport

read -e -p "Enter a new user name to associate with this domain:" -i "admin" user_name


deploy_dir=/var/www/$domain_name/public_html
log_dir=/var/www/$domain_name/logs

if [ ${#user_name} -ne 0 ]; then
	sudo useradd -m -d $deploy_dir -g www-data $user_name
fi

cp /dev/null vhc-includes/virtual-host.conf

if [ ${#localsiteport} -eq 0 ]; then
	echo -e "Creating www dir \n"
	if [ ${#user_name} -eq 0 ]; then
		sudo mkdir -p $deploy_dir
	fi
	sudo mkdir -p $log_dir
	if [ ${#user_name} -eq 0 ]; then
		echo -e "Setting permissions \n"
		sudo chown -R $USER:$USER $deploy_dir
	fi

	sudo chmod -R 755 /var/www

	echo -e "Copying index.html file \n"
	sudo cp vhc-includes/index.html $deploy_dir

	echo -e "Create the New Virtual Host File"
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
	echo -e "Create the New Virtual Host File "
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
echo -e "Reloading apache"
service apache2 reload
