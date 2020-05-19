import requests
import re
import time
import configparser
import ast
import os

config = configparser.ConfigParser()
config.read('config.ini')

api_user = config['API']['user']
api_pass = config['API']['pass']
api_base_url = config['API']['base_url']
dyn_dns_zone = config['Domain']['dyndns_zone']
dyn_dns_subdomain = ast.literal_eval(config.get('Domain', 'dyndns_subdomain'))
log_time = time.strftime('%Y-%m-%d %H:%M')

# Create IP-files
if not os.path.exists('dyndns_ipv4.txt'):
    os.mknod('dyndns_ipv4.txt')

if not os.path.exists('dyndns_ipv6.txt'):
    os.mknod('dyndns_ipv6.txt')

# Get current IPs
ipv4 = requests.get('https://api.ipify.org').text
ipv6 = requests.get('https://api6.ipify.org').text


def get_api_token():
    """ Get valid authentication token """
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


def check_ip_type(ip):
    """ Check IP address format """
    if re.match(r"^\s*\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\s*$", ip):
        return 0
    elif re.match(r"^((([0-9A-Fa-f]{1,4}:){1,6}:)|(([0-9A-Fa-f]{1,4}:){7}))([0-9A-Fa-f]{1,4})$", ip):
        return 1
    else:
        print('{0} [!] No valid IP type'.format(log_time))
    return None


def delete_record(token):
    """ Delete old DNS record """
    api_token = token
    headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer {0}'.format(api_token)}
    api_endpoint = '{0}/dnszones/{1}/records/delete'.format(api_base_url, dyn_dns_zone)
    for i in dyn_dns_subdomain:
        data = {"name": i}
        response = requests.post(api_endpoint, json=data, headers=headers)


def dns_commit(token):
    """ Save changes to DNS server """
    api_token = token
    headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer {0}'.format(api_token)}
    api_endpoint = '{0}/dnszones/{1}/records/commit'.format(api_base_url, dyn_dns_zone)
    response = requests.post(api_endpoint, headers=headers)


def create_record(ip):
    """ Update DNS record with current IP """
    api_token = get_api_token()
    if api_token is not None:
        delete_record(api_token)
        headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer {0}'.format(api_token)}
        api_endpoint = '{0}/dnszones/{1}/records/'.format(api_base_url, dyn_dns_zone)
        if check_ip_type(ip) == 0:
            ip_type = 'A'
        elif check_ip_type(ip) == 1:
            ip_type = 'AAAA'
        else:
            print('{0} [!] Record type error'.format(log_time))
        for i in dyn_dns_subdomain:
            data = {"name": i, "ttl": 1800, "type": ip_type, "data": ip}
            response = requests.post(api_endpoint, json=data, headers=headers)
            print('{0} Subdomain {1} with type {2} and IP {3} updated'.format(log_time, i, ip_type, ip))
        dns_commit(api_token)
    else:
        print('{0} [!] Request Failed'.format(log_time))


# Check current IPv4 address
if check_ip_type(ipv6) == 0:
    with open('dyndns_ipv4.txt', 'r') as fv4:
        if ipv4 in fv4.read():
            print('{0} No IPv4 changes'.format(log_time))
        else:
            fv4 = open("dyndns_ipv4.txt", "w")
            fv4.write(ipv4)
            fv4.close()
            create_record(ipv4)
else:
    print('{0} No IPv4 address available'.format(log_time))

# Check current IPv6 address
if check_ip_type(ipv6) == 1:
    with open('dyndns_ipv6.txt', 'r') as fv6:
        if ipv6 in fv6.read():
            print('{0} No IPv6 changes'.format(log_time))
        else:
            fv6 = open("dyndns_ipv6.txt", "w")
            fv6.write(ipv6)
            fv6.close()
            create_record(ipv6)
else:
    print('{0} No IPv6 address available'.format(log_time))
