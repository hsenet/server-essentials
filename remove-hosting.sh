#!/bin/bash

#syntax  

read -p "Enter Your Domain Name: " domain_name

if [ ${#domain_name} -eq 0 ]; then
	echo "Please give a domain name as an argument"
	exit 1
fi

read -p "Enter a site port or press enter: " localsiteport

read -e -p "Enter the user name associated with this domain else press [enter]: " user_name

deploy_dir=/var/www/$domain_name

if [ ${#localsiteport} -eq 0 ]; then
	echo -e "Disabling site ..."
	sudo a2dissite $domain_name
	echo -e "Removing vertual host entries ..."
	sudo rm -rf /etc/apache2/sites-available/$domain_name.conf
else
	echo -e "Disabling site ..."
	sudo a2dissite $domain_name:$localsiteport
	echo -e "Removing vertual host entries ..."
	sudo rm -rf /etc/apache2/sites-available/$domain_name:$localsiteport.conf
fi


echo -e "Reloading apache ..."
service apache2 reload

if [ ${#user_name} -ne 0 ]; then
	echo -e "Removing user and all directories ..."
	sudo userdel -r $user_name
else 
	echo -e "Removing www directory for this domain ..."
	sudo rm -rf deploy_dir
fi
