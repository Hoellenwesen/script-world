#!/bin/bash

# Script to genrate TLSA records for letsencrypt certificates.

# Define the domain, which is used for the path
# of the /etc/letsencrypt/live/$DOMAIN folder.
DOMAIN="example.com"


if [ "$DOMAIN" == "example.com" ]
then
    echo -e "Please change the \033[91mDOMAIN\033[0m variable in line 7 to match the\
 path of the /etc/letsencrypt/live/<DOMAIN> folder.."
    exit
fi
# Download the last version of the letsencrypt certificate
wget -q -O /etc/letsencrypt/live/$DOMAIN/le-x3-cross-signed.pem \
  https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem.txt

echo "DNS-TLSA resource records for DANE:"
echo "Port       Host         Type                      Destination"

# Create the TLSA entry for the own certificate, use it for all ports
# (change "*" to a specific port like "_25" for port 25/SMTP, if needed).
printf '*._tcp.%s. IN TLSA 3 1 1 %s\n' $(uname -n) $(openssl x509 \
  -in /etc/letsencrypt/live/$DOMAIN/cert.pem -noout -pubkey\
 | openssl pkey -pubin -outform DER | openssl dgst -sha256 -binary\
 | hexdump -ve '/1 "%02x"')

# Create the TLSA entry for the letsencrypt trust anchor
printf '*._tcp.%s. IN TLSA 2 1 1 ' $DOMAIN
openssl x509 -in /etc/letsencrypt/live/$DOMAIN/le-x3-cross-signed.pem\
   -noout -pubkey | openssl rsa -pubin -outform DER 2>/dev/null\
  | openssl dgst -sha256 -hex | sed 's/^.* //'

# Remove the downloaded letsencrypt certificate
rm /etc/letsencrypt/live/$DOMAIN/le-x3-cross-signed.pem
exit
