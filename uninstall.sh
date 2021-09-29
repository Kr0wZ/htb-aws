#!/bin/bash

#For the stop.sh script, just stop the instances, do not terminate them

CURRENT_DIR="$(dirname "$(which $0)")"
CONFIG_FILE="$CURRENT_DIR/htb-aws.conf"

source "$CONFIG_FILE"


#Check if all instances associated with a VPC are terminated if not, terminate them
function check_instances_vpc(){
    NUMBER_INSTANCES=$(aws ec2 describe-instances --region "$REGION" --profile "$USER" --filters "Name=vpc-id,Values=$VPC_ID" --query "Reservations[*].Instances[*].State.Name" --output text|wc -l)
    if [[ ! "$NUMBER_INSTANCES" == "0" ]]
    then
        echo "All instances associated with the current VPC ($VPC_ID) must be terminated to uninstall/reinstall the tool"
        echo -n "Do you want to terminate them? It could take a few minutes [y/n] "
        read ANSWER

        if [[ "$ANSWER" == "y" || "$ANSWER" == "Y" ]]
        then
            echo -e "\e[33m[*] Stopping the instance... 2 minutes remaining\033[0m"
            bash "$CURRENT_DIR/htb-aws-stop.sh"
            #terminate_instances
            #Wait to be sure instance is terminated, else we can't delete security groups and all the stuff
            sleep 120
        else
            echo "Quitting..."
            exit
        fi
    fi
}

# function terminate_instances(){
#     INSTANCES_LIST=$(aws ec2 describe-instances --region "$REGION" --profile "$USER" --filters "Name=vpc-id,Values=$VPC_ID" --query "Reservations[*].Instances[*].InstanceId" --output text)
#     while read -r INSTANCE_ID
#     do
#         aws ec2 terminate-instances --region "$REGION" --profile "$USER" --instance-ids "$INSTANCE_ID" 2>&1 >/dev/null
#     done <<< "$INSTANCES_LIST"
# }


function uninstall(){
    #First check if all instances associated with the VPC are stopped. Else stop them
    check_instances_vpc    
    
    aws ec2 delete-security-group --group-id "$SG_GROUP_ID" --region "$REGION" --profile "$USER"
    echo -e "\e[32m[+] Security group deleted\e[0m"
    aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION" --profile "$USER"
    echo -e "\e[32m[+] Key pair deleted\e[0m"
    aws ec2 delete-subnet --subnet-id "$SUBNET_ID" --region "$REGION" --profile "$USER"
    echo -e "\e[32m[+] Subnet deleted\e[0m"

    aws ec2 detach-internet-gateway --internet-gateway-id "$INTERNET_GATEWAY_ID" --vpc-id "$VPC_ID" --region "$REGION" --profile "$USER"
    echo -e "\e[32m[+] Internet gateway detached\e[0m"
    aws ec2 delete-internet-gateway --internet-gateway-id "$INTERNET_GATEWAY_ID" --region "$REGION" --profile "$USER"
    echo -e "\e[32m[+] Internet gateway deleted\e[0m"

    aws ec2 disassociate-route-table --association-id "$ROUTE_TABLE_ASSOC" --region "$REGION" --profile "$USER" 2>/dev/null
    echo -e "\e[32m[+] Route table disassociated\e[0m"
    aws ec2 delete-route-table --route-table-id "$ROUTE_TABLE_ID" --region "$REGION" --profile "$USER"
    echo -e "\e[32m[+] Route table deleted\e[0m"
    #Find a way to also delete the other VPC created at the same time
    #To delete a VPC we must first stop all instances associated with it and detach all resources (subnets, gateways...)
    aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION" --profile "$USER"
    echo -e "\e[32m[+] VPC deleted\e[0m"

    rm -f "$CONFIG_FILE" "$CURRENT_DIR/$KEY_NAME.pem"

    echo -e "\n\e[32m[+] Successfully uninstalled! If you do not use this tool anymore delete the user 'htb-aws' on AWS\e[0m\n"

}

uninstall