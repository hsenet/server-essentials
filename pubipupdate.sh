#!/bin/bash

PUBIP = curl http://ifconfig.co/

echo "http://$PUBIP:8443/" >> ¬/httpd/index.html