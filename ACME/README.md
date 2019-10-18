# DNS API Core-Networks
Use the script to issue ssl certificates in the Core-Networks DNS server with the acme client "acme.sh" (https://github.com/Neilpang/acme.sh).

First you need to login to your Core-Networks account to create your Username Key and Password.
```
export CN_User=<api_user>
export CN_Pass=<api_password>

acme.sh --issue -d example.com -d '*.example.com' --dns dns_corenetworks
```
The CN_User and CN_Pass will be saved in **~/.acme.sh/account.conf** and will be reused when needed.

#### Software Dependencies
Youe have to install **jq** to process the JSON output of the API request.

###### Ubuntu/Debain
```sh
$ sudo apt install jq
```
