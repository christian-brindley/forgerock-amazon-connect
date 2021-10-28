#!/bin/bash

function usage () {
  echo Usage: install.sh propertiesfile endpointconfig endpoint
}

# getSession amurl userid password
# 
# Get IDC session token
#

function getSession() {
    fqdn=$1
    userid=$2
    password=$3

    authId=$(curl -s  --request POST "https://$fqdn/am/json/authenticate" \
      --header "Accept-API-Version: protocol=1.0,resource=2.1" \
      --header "X-OpenAM-Username: $userid" \
      --header "X-OpenAM-Password: $password"  | jq -r .authId)

    tokenId=$(curl -s --request POST "https://$fqdn/am/json/authenticate" \
      --header "Accept-API-Version: protocol=1.0,resource=2.1" \
      --header "Content-Type: application/json" \
      --data-raw "{\"authId\":\"$authId\",\"callbacks\":[{\"type\":\"TextOutputCallback\",\"output\":[{\"name\":\"message\",\"value\":\"message-008\"},{\"name\":\"messageType\",\"value\":\"0\"}]},{\"type\":\"ConfirmationCallback\",\"output\":[{\"name\":\"prompt\",\"value\":\"\"},{\"name\":\"messageType\",\"value\":0},{\"name\":\"options\",\"value\":[\"Set up\"]},{\"name\":\"optionType\",\"value\":-1},{\"name\":\"defaultOption\",\"value\":0}],\"input\":[{\"name\":\"IDToken2\",\"value\":0}]},{\"type\":\"HiddenValueCallback\",\"output\":[{\"name\":\"value\",\"value\":\"false\"},{\"name\":\"id\",\"value\":\"skip-input-008\"}],\"input\":[{\"name\":\"IDToken3\",\"value\":\"Skip\"}]}]}" | jq -r .tokenId )


    echo $tokenId
}

function getAccessToken() {
    fqdn=$1
    cookieName=$2
    ssotoken=$3

    authcode=$(curl -s -i "https://$fqdn/am/oauth2/authorize?redirect_uri=https://$fqdn/platform/appAuthHelperRedirect.html&client_id=idmAdminClient&response_type=code&scope=fr:idm:*&code_challenge=gX2yL78GGlz3QHsQZKPf96twOmUBKxn1-IXPd5_EHdA&code_challenge_method=S256" \
      --header "Cookie: $cookieName=$ssotoken" | grep "location:" | cut -d" " -f2 | sed -E 's/.*code=([^&]+).*/\1/g' )

    access_token=$(curl -s --request POST "https://$fqdn/am/oauth2/access_token" \
      --header "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "redirect_uri=https://$fqdn/platform/appAuthHelperRedirect.html" \
      --data-urlencode "grant_type=authorization_code" \
      --data-urlencode "client_id=idmAdminClient" \
      --data-urlencode "code=$authcode" \
      --data-urlencode "code_verifier=codeverifier" | jq -r .access_token )

    echo $access_token
}

function getCookieName() {
    fqdn=$1
    cookieName=$(curl -k -s "https://$fqdn/am/json/serverinfo/*" | jq -r .cookieName)
    echo $cookieName
}


function installEndpoint() {
    fqdn=$1
    username=$2
    password=$3
    configfile=$4
    endpoint=$5

    cookieName=$(getCookieName $fqdn)
    ssoToken=$(getSession $fqdn $username $password)
    accessToken=$(getAccessToken $fqdn $cookieName $ssoToken)

    response=$(curl -s -o /dev/null -w "%{http_code}\n" --request PUT "https://$fqdn/openidm/config/endpoint/$endpoint" \
      --header "Authorization: Bearer $accessToken" \
      --header 'Content-Type: application/json' \
      --data-binary "@${configfile}" )

    echo $response
    
}

# Go

if [[ $# != 3 ]]
then
    usage
    exit 1
fi

propertiesfile=$1
configfile=$2
endpoint=$3

if [ ! -f $propertiesfile ]
then
    echo "Properties file $propertiesfile does not exist"
    exit 1
fi

if [ ! -f $configfile ]
then
    echo "Config file $configfile does not exist"
    exit 1
fi

. $propertiesfile

response=$(installEndpoint "$FQDN" "$ADMIN_USERNAME" "$ADMIN_PASSWORD" "$configfile" "$endpoint")
echo Response: $response
