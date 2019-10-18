#!/usr/bin/env sh

# DNS API for acme.sh for users using Core-Networks (https://beta.api.core-networks.de/doc/).
# Created by Sebastian Weyer 2018-04-20.

API_URL="https://beta.api.core-networks.de"

########  Public functions #####################

# Adds a TXT DNS record.
dns_corenetworks_add() {
  fulldomain=$1
  txtvalue=$2

  _info "Using Core-Netwroks API"
  _info fulldomain "$fulldomain"
  _info txtvalue "$txtvalue"

  CN_User="${CN_User:-$(_readaccountconf_mutable CN_User)}"
  CN_Pass="${CN_Pass:-$(_readaccountconf_mutable CN_Pass)}"
  if [ -z "$CN_User" ]; then
    _err "You must export variable: CN_User"
    return 1
  fi
  if [ -z "$CN_Pass" ]; then
    _err "You must export variable: CN_Pass"
    return 1
  fi

  # Now save the credentials.
  _saveaccountconf_mutable CN_Pass "$CN_Pass"
  _saveaccountconf_mutable CN_User "$CN_User"

  if ! _cn_get_domain; then
    return 1
  fi

  if ! _cn_get_token; then
    return 1
  fi

  export _H1="Authorization: Bearer $CN_Token"

  # Add the record
  data="{\"name\":\"$_cn_sub\",\"ttl\":300,\"type\":\"TXT\",\"data\":\"$txtvalue\"}"
  _debug "Data: $data"
  add_rec=$(_post "$data" "$API_URL/dnszones/$_cn_domain/records/")

  # Commit changes to DNS server
  commit=$(_post "" "$API_URL/dnszones/$_cn_domain/records/commit")

  return 0
}

# Removes the TXT record after validation.
dns_corenetworks_rm() {
  fulldomain=$1
  txtvalue=$2

  _info "Using Core-Netwroks API"
  _info fulldomain "$fulldomain"
  _info txtvalue "$txtvalue"

  if ! _cn_get_domain; then
    return 1
  fi

  if ! _cn_get_token; then
    return 1
  fi

  export _H1="Authorization: Bearer $CN_Token"

  # Delete TXT record
  data="{\"data\":\"$txtvalue\"}"
  _debug "Data: $data"
  del_rec=$(_post "$data" "$API_URL/dnszones/$_cn_domain/records/delete")

  # Commit changes to DNS server
  commit=$(_post "" "$API_URL/dnszones/$_cn_domain/records/commit")

  return 0
}

####################  Private functions below ##################################

# Extracts domain and subdomain
_cn_get_domain() {
  _cn_domain="$(echo $fulldomain | rev | cut -d . -f 1,2 | rev)"
  _cn_sub="$(echo $fulldomain | rev | cut -d . -f 3- | rev)"

  if [ -z "$_cn_domain" ]; then
    _err "Error extracting the domain."
    return 1
  fi

  _debug "fulldomain: $fulldomain, domain: $_cn_domain, sub: $_cn_sub"

  return 0
}

# Requests auth token
_cn_get_token() {
  CN_User="$(_readaccountconf_mutable CN_User)"
  CN_Pass="$(_readaccountconf_mutable CN_Pass)"
  
  data="{\"login\":\"$CN_User\",\"password\":\"$CN_Pass\"}"
  _debug "Data: $data"
  get_token=$(_post "$data" "$API_URL/auth/token")
  _debug "Get token: $get_token"
  
  CN_Token=$(echo $get_token | jq -r '.token')
  _debug "Token: $CN_Token"

  if [ -z "$CN_Token" ]; then
    _err "No token received"
    return 1
  fi

  return 0
}
