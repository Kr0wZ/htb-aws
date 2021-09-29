#!/bin/bash

CURRENT_DIR="$(dirname "$(which $0)")"
CONFIG_FILE="$CURRENT_DIR/htb-aws.conf"

#Must choose "htb-aws" as IAM user
USER="htb-aws"
SG_NAME="htb-aws-sg"
KEY_NAME="htb-aws-key"
#You can change the ports
OPEN_PORTS="1337,4444,5555,6666"

function usage(){
	echo "$0" "-f"
	exit 1
}


function check_error(){
	if [[ "$?" != 0 ]]
	then
		echo "An error occured"
	fi
}

function get_current_region(){
	REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
	check_error
}

function create_security_group(){
	SG_GROUP_ID=$(aws ec2 create-security-group --group-name "$SG_NAME" --description "Security group for HTB using EC2 instances" --vpc-id "$VPC_ID" --profile "$USER" --region "$REGION" |grep "GroupId"| cut -d '"' -f4)
	check_error
	echo -e "\e[32m[+] Security group created\e[0m"
}

function add_ingress_rules(){
	#Must specify --group-id instead of --group-name for a non default VPC
	aws ec2 authorize-security-group-ingress --group-id "$SG_GROUP_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --profile "$USER" --region "$REGION" 2>/dev/null
	check_error

	while read -r PORT
	do
		aws ec2 authorize-security-group-ingress --group-id "$SG_GROUP_ID" --protocol tcp --port "$PORT" --cidr 0.0.0.0/0 --profile "$USER" --region "$REGION"
	done <<< $(echo "$OPEN_PORTS"|tr "," "\n" )

	echo -e "\e[32m[+] Ingress rules added to security group\e[0m"
}

function create_key_pair(){
	aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$KEY_NAME.pem" --profile "$USER" --region "$REGION" 2>/dev/null
	chmod 400 "$KEY_NAME.pem"
	check_error
	echo -e "\e[32m[+] SSH key created\e[0m"
}

function create_vpc(){
	VPC_ID=$(aws ec2 create-vpc --cidr-block 192.168.0.0/16 --profile "$USER" --region "$REGION" |grep -e VpcId |cut -d '"' -f4)
	check_error
	echo -e "\e[32m[+] VPC created\e[0m"
}

function create_subnet(){
	SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 192.168.1.0/24 --profile "$USER" --region "$REGION" |grep -e SubnetId|cut -d '"' -f4)
	check_error
	echo -e "\e[32m[+] Subnet linked to VPC created\e[0m"
}


function get_kali_ami(){
	AMI_ID=$(aws ec2 describe-images --profile "$USER" --owners aws-marketplace --region "$REGION" --filters "Name=name,Values=kali-linux-2021.2rc3-804fcc46-63fc-4eb6-85a1-50e66d6c7215" --query "Images[0].ImageId" --output text)
	check_error
	echo -e "\e[32m[+] Kali AMI retrieved from AWS marketplace\e[0m"
}

function create_internet_gateway(){
	INTERNET_GATEWAY_ID=$(aws ec2 create-internet-gateway --region "$REGION" --profile "$USER" --query 'InternetGateway.InternetGatewayId' --output text)
	check_error
	echo -e "\e[32m[+] Internet gateway created\e[0m"
}

function attach_internet_gateway(){
	aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$INTERNET_GATEWAY_ID" --region "$REGION" --profile "$USER"
	check_error
	echo -e "\e[32m[+] Internet gateway attached to VPC\e[0m"
}

function create_route_table(){
	ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query "RouteTable.RouteTableId" --output text --region "$REGION" --profile "$USER")
	check_error
	echo -e "\e[32m[+] Route table associated with VPC created\e[0m"
}

#Why 2 routes are created???
function create_route(){
	#How to get his id? Nothing is returned
	aws ec2 create-route --route-table-id "$ROUTE_TABLE_ID" --destination-cidr-block "0.0.0.0/0" --gateway-id "$INTERNET_GATEWAY_ID" --region "$REGION" --profile "$USER" 2>&1 >/dev/null
	echo -e "\e[32m[+] Route between VPC and Internet added\e[0m"
}

function associate_route_table(){
	ROUTE_TABLE_ASSOC=$(aws ec2 associate-route-table --route-table-id "$ROUTE_TABLE_ID"  --region "$REGION" --profile "$USER" --subnet-id "$SUBNET_ID" --query "AssociationId" --output text 2>/dev/null)
	echo -e "\e[32m[+] Association successfully made between route table and subnet\e[0m"
}

function create_config_file(){
	content="#AWS variables
#You can change the following options:
#Make sure you have at least the port 1337 open for the VPN configuration (in HTB you can also choose port 443 for the openvpn file. In this case adapt it).
OPEN_PORTS=\""$OPEN_PORTS\""
#Free tier instance by default.
INSTANCE_TYPE=\""t2.micro\""
#You can choose you own distribution instead of Kali Linux image but make sure to change the AMI_USER variable too.
AMI_ID=\""$AMI_ID\""
#Default user for Kali Linux to connect to the instance.
AMI_USER=\""kali\""
#Your current region by default.
REGION=\""$REGION\""

#Do not change these variables
USER=\""$USER\""
VPC_ID=\""$VPC_ID\""
SUBNET_ID=\""$SUBNET_ID\""
SG_GROUP_ID=\""$SG_GROUP_ID\""
INTERNET_GATEWAY_ID=\""$INTERNET_GATEWAY_ID\""
ROUTE_TABLE_ID=\""$ROUTE_TABLE_ID\""
ROUTE_TABLE_ASSOC=\""$ROUTE_TABLE_ASSOC\""
KEY_NAME=\""$KEY_NAME\""
SSH_KEY=\""$CURRENT_DIR/$KEY_NAME.pem\""

#Variables for the progress bar
START=0
END=100
STEP=1"

echo "$content" > "$CONFIG_FILE"

}

function setup(){
	get_current_region
	get_kali_ami
	create_key_pair
	create_vpc
	create_subnet
	create_security_group
	add_ingress_rules

	create_internet_gateway
	attach_internet_gateway
	create_route_table
	create_route
	associate_route_table
	
	create_config_file

	echo -e "\nYou are now ready to spawn instances! Enjoy :)"
}

#If the CLI isn't configured yet
if [[ ! -f ~/.aws/credentials ]]
then
	echo "You must configure the aws cli first"
	exit
fi

#If the tool has already been installed
if [[ -f "$CONFIG_FILE" ]]
then
	while getopts "f" option; do
	    case "${option}" in
	        f)
				echo -e "\e[33m[*] Reinstalling the script...\033[0m"
				#Uninstall the script
	          	bash "$CURRENT_DIR/uninstall.sh" 2>/dev/null
	          	#Install it again
	          	bash "$0"
	          	exit
		        ;;
	        *)
	            usage
	            ;;
	    esac
	done

	echo -e "You've already configured the tool. If you want to reinstall it and generate new resources run the -f option\n"
	exit
fi

setup