#!/bin/bash

#syntax  

read -p "Enter Your Domain Name: " domain_name

if [ ${#domain_name} -eq 0 ]; then
	echo "Please give a domain name as an argument"
	exit 1
fi

read -p "Enter a site port or press enter: " localsiteport

read -r -p "Need a new user name to associate with this domain? [y/n] " new_user_name


if [[ $new_user_name =~ ^[Yy]$ ]]; then
	read -e -p "Enter a new user name to associate with this domain: " user_name
else
	read -e -p "Enter an existing user name to associate with this domain: " -i "admin" user_name
fi

deploy_dir=/var/www/$domain_name
www_dir=/var/www/$domain_name/public_html
log_dir=/var/www/$domain_name/logs

cp /dev/null vhc-includes/virtual-host.conf

if [ ${#localsiteport} -eq 0 ]; then
	echo -e "Creating www dir ..."
	sudo mkdir -p $deploy_dir
	sudo mkdir -p $www_dir
	sudo mkdir -p $log_dir
	echo -e "Setting permissions ..."
	sudo chown -R $USER:$USER $deploy_dir

	sudo chmod -R 755 /var/www

	echo -e "Copying index.html file ..."
	sudo cp vhc-includes/index.html $deploy_dir

	echo -e "Create the New Virtual Host File ..."
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
	echo -e "Create the New Virtual Host File ..."
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
echo -e "Reloading apache ..."
service apache2 reload

if [[ $new_user_name =~ ^[Yy]$ ]]; then
	echo -e "Creating user $user_name ..."
	sudo useradd -d $deploy_dir -g www-data $user_name
	echo -e "Setting password ..."
	sudo passwd $user_name
	echo -e "Setting permissions to user created above ..."
	sudo chown -R $user_name:www-data $deploy_dir
	
else 
	sudo chown -R $user_name:www-data $deploy_dir
fi

echo -e "Done!"