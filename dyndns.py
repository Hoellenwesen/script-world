import json
import requests
import re
import time

api_user = 'xxxxxxxx'
api_pass = 'xxxxxxxx'
api_base_url = 'https://beta.api.core-networks.de'
dyn_dns_zone = 'YOUR_BASE_DOMAIN'
dyn_dns_subdomain = ['SUBDOMAIN_1', 'SUBDOMAIN_2']
logtime = time.strftime('%Y-%m-%d %H:%M')

### Get current IPs
ipv4 = requests.get('https://api.ipify.org').text
ipv6 = requests.get('https://api6.ipify.org').text

### Get valid authentication token
def get_api_token():
    headers = {'Content-type': 'application/json'}
    api_endpoint = '{0}/auth/token'.format(api_base_url)
    data = {"login": api_user, "password": api_pass}

    response = requests.post(api_endpoint, json=data, headers=headers)

    if response.status_code >= 500:
        print('[!] [{0}] Server Error'.format(response.status_code))
        return None
    elif response.status_code == 404:
        print('[!] [{0}] URL not found: [{1}]'.format(response.status_code,api_url))
        return None  
    elif response.status_code == 401:
        print('[!] [{0}] Authentication Failed'.format(response.status_code))
        return None
    elif response.status_code == 400:
        print('[!] [{0}] Bad Request'.format(response.status_code))
        return None
    elif response.status_code >= 300:
        print('[!] [{0}] Unexpected Redirect'.format(response.status_code))
        return None
    elif response.status_code == 200:
        result = response.json()
        token = result['token']
        return token
    else:
        print('[?] Unexpected Error: [HTTP {0}]: Content: {1}'.format(response.status_code, response.content))
    return None

### Check IP address format
def check_ip_type(ip):
    if re.match(r"^\s*\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\s*$", ip):
        return 0
    elif re.match(r"^((([0-9A-Fa-f]{1,4}:){1,6}:)|(([0-9A-Fa-f]{1,4}:){7}))([0-9A-Fa-f]{1,4})$", ip):
        return 1
    else:
        print('{0} [!] No valid IP type'.format(logtime))
    return None

### Delete old DNS record
def delete_record(token):
    api_token = token
    headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer {0}'.format(api_token)}
    api_endpoint = '{0}/dnszones/{1}/records/delete'.format(api_base_url, dyn_dns_zone)
    for i in dyn_dns_subdomain:
        data = {"name": i}
        response = requests.post(api_endpoint, json=data, headers=headers)

### Save changes to DNS server
def dns_commit(token):
    api_token = token
    headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer {0}'.format(api_token)}
    api_endpoint = '{0}/dnszones/{1}/records/commit'.format(api_base_url, dyn_dns_zone)
    response = requests.post(api_endpoint, headers=headers)

### Update DNS record with current IP
def create_record(ip):
    api_token = get_api_token()
    if api_token is not None:
        delete_record(api_token)
        headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer {0}'.format(api_token)}
        api_endpoint = '{0}/dnszones/{1}/records/'.format(api_base_url, dyn_dns_zone)
        if check_ip_type(ip) is 0:
            type = 'A'
        elif check_ip_type(ip) is 1:
            type = 'AAAA'
        else:
            print('{0} [!] Record type error'.format(logtime))
        for i in dyn_dns_subdomain:
            data = {"name": i, "ttl": 1800, "type": type, "data": ip}
            response = requests.post(api_endpoint, json=data, headers=headers)
            print('{0} Subdomain {1} with type {2} and IP {3} updated'.format(logtime, i, type, ip))
        dns_commit(api_token)
    else:
        print('{0} [!] Request Failed'.format(logtime))

### Check current IPv4 address
with open('dyndns_ipv4.txt','r') as fv4:
    if ipv4 in fv4.read():
        print('{0} No IPv4 changes'.format(logtime))
    else:
        fv4 = open("dyndns_ipv4.txt", "w")
        fv4.write(ipv4)
        fv4.close()
        create_record(ipv4)

### Check current IPv6 address
with open('dyndns_ipv6.txt','r') as fv6:
    if ipv6 in fv6.read():
        print('{0} No IPv6 changes'.format(logtime))
    else:
        fv6 = open("dyndns_ipv6.txt", "w")
        fv6.write(ipv6)
        fv6.close()
        create_record(ipv6)

