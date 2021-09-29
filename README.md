## Presentation

This tool uses the EC2 instances from AWS to spawn a Kali Linux virtual machine in the cloud, directly connected to the HTB lab.

You can reuse this code as you want and make modifications but please do not forget to mention my work. Thanks!


## Prerequisites:

- AWS account (free tier is working)
- HackTheBox account and openvpn file to connect to the VPN lab
- Right to create a new user in AWS.

## How to create a new IAM user in AWS console?

1) In the AWS console go to services (upper left).
2) Select **IAM** under the Security, Identity & Compliance section or search in the top search bar "iam".
3) In IAM, select **Users** in the navigation panel on the left.
4) Click **Add user** (top right blue button)
5) Fill out the user name filed with **htb-aws**, and for access type, select **"Access key - Programmatic access"**.
6) Select the option named **Attach existing policies directly**. Search and add the policy **AmazonEC2FullAccess**.
7) Copy the access key and secret. Be careful! Once this page left it is not possible anymore to retrieve these credentials. You will need to delete this one and create a new user.
8) Use the aws configure command:
```bash
aws configure --profile htb-aws
```
- In ~/.aws/credentials you should find something similar to this:
```
\<Potential other credentials...\>
[htb-aws]
aws_access_key_id = AKIAXXXXXXXXXXXXXXXX
aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

## Installation

All the installation can be made **without sudo** rights.

Give execution permission to the **setup.sh** script and execute it.
All the important files will be stored in the same directory.

You can now run your own Kali Linux machine in the cloud and hack HTB machines!

## Usage

```bash
./htb-aws-spawn.sh -f <htb_lab.ovpn> [-r]
```

/!\ Before launching the scripts, make sure you have completed the prerequisites above.

Once the installation completed you can directly spawn a Kali Linux instance in the cloud by executing the script **htb-aws-spawn.sh** (don't forget to give execution permission). You must specify the openvpn file wih the option **-f**.

If another instance is already running you have to specify the -r option to stop it and restart a new one.
/!\ -r option will erase all data stored in the current running instance!

The script **htb-aws-stop.sh** can be executed to stop the running instance.

## Configuration

Once the installation completed you can modify some options in the configuration file **htb-aws.conf**:

- OPEN_PORTS -> Choose the open ports. Make sure you have at least the port 1337 open for the VPN configuration (in HTB you can also choose port 443 for the openvpn file. In this case adapt it).
- INSTANCE_TYPE -> Free tier instance by default.
- AMI_ID -> You can choose you own distribution instead of Kali Linux image but make sure to change the AMI_USER variable too (For example, with Ubuntu distribution the default user is "ubuntu").
- AMI_USER -> Default user to connect to the instance.
- REGION -> Region when resources will be created. Your current region by default.

## Contact

If you have any questions do not hesitate to contact me: 
- Discord -> KrowZ#3603
- Twitter -> [@ZworKrowZ](https://twitter.com/ZworKrowZ)

## Removing the tool

To uninstall the tool you only need to execute the **uninstall.sh** script.

## Potential errors

In case of errors in the scripts you can manually delete the created resources from the AWS console ()