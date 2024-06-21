#!/bin/bash

# Multiple clients can be added by running the script multiple times
if readlink /proc/$$/exe | grep -q "dash"; then
    echo 'This installer needs to be run with "bash", not "sh".'
    exit
fi

# Discard stdin. Needed when running from a one-liner which includes a newline
read -N 999999 -t 0.001

new_client () {
    # Generates the custom client.ovpn
    {
        cat /etc/openvpn/server/client-common.txt
        echo "<ca>"
        cat /etc/openvpn/server/easy-rsa/pki/ca.crt
        echo "</ca>"
        echo "<cert>"
        sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt
        echo "</cert>"
        echo "<key>"
        cat /etc/openvpn/server/easy-rsa/pki/private/"$client".key
        echo "</key>"
        echo "<tls-crypt>"
        sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/server/tc.key
        echo "</tls-crypt>"
    } > ~/"$client".ovpn
}

if [[ ! -e /etc/openvpn/server/server.conf ]]; then
    echo "OpenVPN is not installed. Installing now..."
    curl -O https://raw.githubusercontent.com/surpriseawofemi/openvpn-install/master/openvpn-install.sh
    chmod +x openvpn-install.sh
    ./openvpn-install.sh
else
    clear
    echo "OpenVPN is already installed."
    echo
    echo "How many clients do you want to add?"
    read -p "Number of clients: " number_of_clients
    until [[ "$number_of_clients" =~ ^[0-9]+$ && "$number_of_clients" -gt 0 ]]; do
        echo "$number_of_clients: invalid selection."
        read -p "Number of clients: " number_of_clients
    done

    echo
    echo "Provide a base name for the clients:"
    read -p "Base name: " unsanitized_base_name
    base_name=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_base_name")
    while [[ -z "$base_name" ]]; do
        echo "$base_name: invalid base name."
        read -p "Base name: " unsanitized_base_name
        base_name=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_base_name")
    done

    for ((i = 1; i <= number_of_clients; i++)); do
        client="${base_name}${i}"
        while [[ -e /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt ]]; do
            i=$((i+1))
            client="${base_name}${i}"
        done

        cd /etc/openvpn/server/easy-rsa/
        ./easyrsa --batch --days=3650 build-client-full "$client" nopass
        # Generates the custom client.ovpn
        new_client
        echo
        echo "$client added. Configuration available in:" ~/"$client.ovpn"
    done
    exit
fi
