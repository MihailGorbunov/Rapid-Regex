#!/bin/bash

# Запуск скрипта из папки скрипта родителя
cd "$(dirname "$0")"

echo "CONFIG VERSION 2.0"

# XRay config

rm /output/config.json
cp config.json ./output/config.json

touch ./output/env.txt
# Prefer reading server name from mounted file; fallback to env NAME; then hostname
if [ -f "/server_name.txt" ]; then
    NAME=$(head -n 1 /server_name.txt | tr -d '\r')
fi
if [ -z "${NAME:-}" ]; then
    NAME=$(hostname -s 2>/dev/null || hostname)
fi

echo $SNI >> ./output/env.txt
echo $NAME >> ./output/env.txt
echo $USERCOUNT >> ./output/env.txt

key_x25519=$(./xray x25519)
PKEY=$(echo "$key_x25519" | awk '/Private key:/ {print $3}')
PUBKEY=$(echo "$key_x25519" | awk '/Public key:/ {print $3}')

SID=$(openssl rand -hex 8)

sed -i -e "s/#PKEY/$PKEY/g" ./output/config.json
sed -i -e "s/#SID/$SID/g" ./output/config.json
sed -i -e "s/#SNI/$SNI/g" ./output/config.json

# Connection string for ease of access

#cp -fr connstring.txt /connection/connstring.txt
IP=$(curl ipinfo.io/ip)

BASECONNSTRING=`cat connstring.txt`
BASECONNSTRING=$(echo "$BASECONNSTRING" |
sed "s/#IP/$IP/g" |
sed "s/#SNI/$SNI/g" |
sed "s/#PUBKEY/$PUBKEY/g" |
sed "s/#SID/$SID/g")

# Generate users

CLIENTSARRAY=''
CONNSTRINGARRAY=''
CONNECTIONS_JSON_OBJECTS=''
for i in $(seq 1 $USERCOUNT);
do
    # New entry in config.json
    NEWCLIENT=`cat client.json`
    UUID=$(./xray uuid)
    NEWCLIENT=$(echo "$NEWCLIENT" | sed "s/#UUID/$UUID/g" | sed "s/#USERNAME/${NAME}_$i/g")    
    if [ ! $i = $USERCOUNT ]; then
    NEWCLIENT+=$',@'
    fi
    CLIENTSARRAY+=$NEWCLIENT

    # New entry in connstring.txt
    NEWCONNSTRING="${NAME}_$i:"$'\n'
    NEWCONNSTRING+=$BASECONNSTRING
    NEWCONNSTRING=$(echo "$NEWCONNSTRING" | sed "s/#UUID/$UUID/g") 
    NEWCONNSTRING=$(echo "$NEWCONNSTRING" | sed "s/#NAME/"$NAME"_"$i"/g")
    
    CONNSTRINGARRAY+=$NEWCONNSTRING$'\n'

    # Append JSON object for this connection (for registration payload)
    CONN_OBJ=$(jq -n \
        --arg connName "${NAME}_$i" \
        --arg server "$IP" \
        --arg server_port "443" \
        --arg pbk "$PUBKEY" \
        --arg uuid "$UUID" \
        --arg sid "$SID" \
        --arg sni "$SNI" \
        '{connName:$connName, server:$server, server_port:$server_port, pbk:$pbk, uuid:$uuid, sid:$sid, sni:$sni}')
    if [ -n "$CONNECTIONS_JSON_OBJECTS" ]; then
        CONNECTIONS_JSON_OBJECTS+=','
    fi
    CONNECTIONS_JSON_OBJECTS+=$CONN_OBJ
done

touch ./output/connstring.txt
echo "$CONNSTRINGARRAY" > ./output/connstring.txt

# Write machine-readable list of all connections for registration
echo "[$CONNECTIONS_JSON_OBJECTS]" > ./output/connections.json

sed -i -e "s|#CLIENTS|$CLIENTSARRAY|g" ./output/config.json
sed -i -e "s|@|\\n|g" ./output/config.json

# Connection file to serve on nginx
rm ./output/connection.txt
touch ./output/connection.txt

echo '{' >> ./output/connection.txt
echo "\"PBK\" : \"$PUBKEY\"," >> ./output/connection.txt
echo "\"UUID\" : \"$UUID\"," >> ./output/connection.txt
echo "\"SID\" : \"$SID\"," >> ./output/connection.txt
echo "\"IP\" : \"$IP\"," >> ./output/connection.txt
echo "\"SNI\" : \"$SNI\"" >> ./output/connection.txt
echo '}' >> ./output/connection.txt

echo "Configuration is complete"