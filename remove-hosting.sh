#!/bin/bash

#syntax  

read -p "Enter Your Domain Name: " domain_name

if [ ${#domain_name} -eq 0 ]; then
	echo "Please give a domain name as an argument"
	exit 1
fi

read -p "Enter a site port or press enter: " localsiteport

read -e -p "Enter the user name associated with this domain:" -i "admin" user_name

if [ ${#localsiteport} -eq 0 ]; then
	sudo a2dissite $domain_name
	sudo rm -rf /etc/apache2/sites-available/$domain_name.conf
else
	sudo a2dissite $domain_name:$localsiteport
	sudo rm -rf /etc/apache2/sites-available/$domain_name:$localsiteport.conf
fi
echo -e "Reloading apache"
service apache2 reload

if [ ${#user_name} -ne 0 ]; then
	userdel -r $user_name
fi
