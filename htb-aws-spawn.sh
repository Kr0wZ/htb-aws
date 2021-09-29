#!/bin/bash

#Check if file exists. If not it means the setup has not been done.
source htb-aws.conf

CURRENT_DIR="$(dirname "$(which $0)")"
INSTANCE_FILE="$CURRENT_DIR/running_instance.txt"

function usage(){
	echo "usage: $0" "-f <htb_lab.ovpn> [-r]"
	exit 1
}

function spawn_instance(){
	EC2_ID=$(aws ec2 run-instances --profile "$USER" --region "$REGION" --image-id "$AMI_ID" --count 1 --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" --security-group-ids "$SG_GROUP_ID" --subnet-id "$SUBNET_ID" --associate-public-ip-address  --tag-specifications 'ResourceType=instance,Tags=[{Key=WatchTower,Value="$tag"},{Key=AutomatedID,Value="$uid"}]' | grep InstanceId | cut -d":" -f2 | cut -d'"' -f2)
	ELASTIC_IP=$(aws ec2 describe-instances --profile "$USER" --region "$REGION" --instance-ids $EC2_ID --query 'Reservations[0].Instances[0].PublicIpAddress' | cut -d '"' -f2)

	echo "$EC2_ID:$ELASTIC_IP" >> "$INSTANCE_FILE"
}

#Progress bar function, only aesthetic
function progress_bar {
    let PROGRESS=(${1}*100/${2}*100)/100
    let DONE=(${PROGRESS}*4)/10
    let LEFT=40-$DONE

    FILL=$(printf "%${DONE}s")
    EMPTY=$(printf "%${LEFT}s")

	printf "\rProgress : [${FILL// /#}${EMPTY// /-}] ${PROGRESS}%%"
}

function ssh_initialization(){
	#Wait for some time to let the SSH initialization.
	echo -e "\e[33m ========= | Instantiation | =========\033[0m\n"
	for nb in $(seq ${START} ${STEP} ${END})
	do
	    sleep 1
		progress_bar ${nb} ${END}
	done
}

function upload_connection_file(){
	echo -e "\e[33m[*] Uploading connection file...\033[0m"
	scp -q -o 'StrictHostKeyChecking no' -i "$KEY_NAME.pem" "$OPENVPN_FILE" "$AMI_USER@$ELASTIC_IP:./" 2>/dev/null
	echo -e "\e[32m[+] File uploaded\e[0m"
}

function install_firefox(){
	echo -e "\n\n\e[33m[*] Instance configuration... Could take a few minutes\033[0m"
	ssh -q -o 'StrictHostKeyChecking no' -i "$KEY_NAME.pem" "$AMI_USER@$ELASTIC_IP" "sudo apt-get update 2>&1 >/dev/null && sudo apt-get install -y firefox-esr 2>&1 >/dev/null" >/dev/null
}

function check_instance_running(){
	if [[ -f "$INSTANCE_FILE" ]] && [[ "$BYPASS_CHECK" == true ]]
	then
		ELASTIC_IP=$(cat "$INSTANCE_FILE"|cut -d ":" -f2)
		echo "Warning! An instance is already running"
		echo "Specify the -r option to restart a new one and terminate the current instance or simply connect to it with: ssh -X -i $KEY_NAME.pem  $AMI_USER@$ELASTIC_IP"
		exit
	fi
}

#Manage options
while getopts ":f:r" OPTION; do
    case "$OPTION" in
        f)
            OPENVPN_FILE="$OPTARG"
            BYPASS_CHECK=true
            ;;
        r)
			bash "$CURRENT_DIR/htb-aws-stop.sh"
			#If we restart the instance then we bypass the verification to avoid an infinite loop
			BYPASS_CHECK=false
			#Error here when we try to connect to the VPN for the second time
			#Remove all the -q and 2>/dev/null for the scp and ssh commands to debug
			#bash "$0" "-f $OPENVPN_FILE"
			#exit
			;;
        *)
            usage
            exit
            ;;
    esac
done

shift $((OPTIND-1))

if [ -z "$OPENVPN_FILE" ]
then
    usage
    exit
fi

check_instance_running

spawn_instance

#If null ip found (it happens sometimes) then stop the instance and start a new one
while [ "$ELASTIC_IP" == "null" ]
do
	echo -e "\e[31m[-] Null ip found!\e[0m"
	echo -e "\e[32m[+] Stopping $EC2_ID\e[0m"
	aws ec2 terminate-instances --profile "$USER" --region "$REGION" --instance-ids "$EC2_ID" 2>&1 >/dev/null
	echo -e "\e[32m[+] Spawn new instance to replace the previous one\e[0m\n"

	spawn_instance
done


ssh_initialization

install_firefox

upload_connection_file

#Run openvpn client in the background.
PID=$(ssh -q -i "$KEY_NAME.pem" "$AMI_USER@$ELASTIC_IP" "(nohup sudo openvpn "$OPENVPN_FILE" > /dev/null 2>&1 &; echo \$!)")

sleep 3
RETURN_CODE=$(ssh -q -i "$KEY_NAME.pem" "$AMI_USER@$ELASTIC_IP" "(kill -0 $PID 2>/dev/null; echo \$?)")

if [[ "$RETURN_CODE" -eq 1 ]]
then
	echo -e "\e[31m[-] Failed to connect to the HTB VPN server :( Verify your file's configuration\e[0m"
	bash "$CURRENT_DIR/htb-aws-stop.sh"
else
	ip_addr=$(ssh -q -i "$KEY_NAME.pem" "$AMI_USER@$ELASTIC_IP" "ip addr show tun0 | grep -Po 'inet \K[\d.]+'")

	echo -e "\e[32m[+] Connected to HTB lab\e[0m"
	echo -e "\e[32m[+] Connected to the $AMI_USER instance\e[0m"
	echo -e "\nYour IP in the lab:\e[31m $ip_addr\e[0m"
	echo -e "Your public IP:\e[31m $ELASTIC_IP\e[0m"
	echo -e "Available open ports:\e[31m $OPEN_PORTS\e[0m"
	echo -e "\nIf needed you can open firefox using the \"firefox -no-remote >/dev/null 2>&1 &\" command\n"

	ssh -q -i "$KEY_NAME.pem" "$AMI_USER@$ELASTIC_IP" "touch /home/$AMI_USER/.Xauthority /home/$AMI_USER/.hushlogin"

	ssh -X -i "$KEY_NAME.pem" -o 'LogLevel=QUIET' "$AMI_USER@$ELASTIC_IP" 2>/dev/null

	echo -e "\nDo not forget to stop current instance if it's not needed anymore using the stop-instance.sh script!"
	echo -e "If you want to reconnect to the instance: ssh -X -i $KEY_NAME.pem  $AMI_USER@$ELASTIC_IP\n"
fi