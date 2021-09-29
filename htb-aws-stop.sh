#!/bin/bash

CURRENT_DIR="$(dirname "$(which $0)")"
INSTANCE_FILE="$CURRENT_DIR/running_instance.txt"

source "$CURRENT_DIR/htb-aws.conf"

#Check if instance are running
if [ -f "$INSTANCE_FILE" ]
then
	ID=$(cat "$INSTANCE_FILE" | cut -d ":" -f1)
	ELASTIC_IP=$(cat "$INSTANCE_FILE" | cut -d ":" -f2)
	echo -e "\e[33m[*] Stopping $ELASTIC_IP\e[0m"
	aws ec2 terminate-instances --instance-ids "$ID" --profile "$USER" --region "$REGION" 2>&1 >/dev/null
	echo -e "\e[32m[+] Instance $ELASTIC_IP stopped\e[0m\n"
	rm -f "$INSTANCE_FILE"

fi