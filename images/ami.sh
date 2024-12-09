#!/bin/zsh
set -euo pipefail

export AWS_PAGER=""
BASE_AMI_ID="ami-0704ab24024610412"
#amazon/amzn2-ami-minimal-hvm-2.0.20230727.0-x86_64-ebs
INSTANCE_TYPE="t2.micro"
AMI_NAME="MyCustomAMI"
TEMP_KEY_NAME="temp-key-$(date +%s)"
TEMP_SG_NAME="temp-sg-$(date +%s)"
TEMP_KEY_PATH="/tmp/$TEMP_KEY_NAME.pem"

cleanup() {
  echo "Cleaning up temporary resources..."
  [[ -f $TEMP_KEY_PATH ]] && rm $TEMP_KEY_PATH
  aws ec2 describe-key-pairs --key-names $TEMP_KEY_NAME &> /dev/null && aws ec2 delete-key-pair --key-name $TEMP_KEY_NAME
  aws ec2 describe-security-groups --group-names $TEMP_SG_NAME &> /dev/null && aws ec2 delete-security-group --group-id $TEMP_SG_ID
  echo "Temporary key pair and security group deleted"
}

# Trap EXIT signal from script to ensure cleanup is called on any exit
trap cleanup EXIT

create_key_pair() {
  echo "Creating temporary key pair..."
  aws ec2 create-key-pair --key-name $TEMP_KEY_NAME --query 'KeyMaterial' --output text > $TEMP_KEY_PATH
  chmod 400 $TEMP_KEY_PATH
  echo "Temporary key pair created: $TEMP_KEY_NAME"
}

create_security_group() {
  echo "Creating temporary security group..."
  # VPC 0 = uat-vpc
  VPC_ID=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text)
  TEMP_SG_ID=$(aws ec2 create-security-group --group-name $TEMP_SG_NAME --description "Temporary security group" --vpc-id $VPC_ID --query 'GroupId' --output text)
  aws ec2 authorize-security-group-ingress --group-id $TEMP_SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --output text
  echo "Temporary security group created: $TEMP_SG_NAME ($TEMP_SG_ID)"
}

# TODO add subnet
launch_instance() {
  echo "Launching instance..."
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $BASE_AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $TEMP_KEY_NAME \
    --security-group-ids $TEMP_SG_ID \
    --query 'Instances[0].InstanceId' \
    --output text)
  echo "Instance launched with ID: $INSTANCE_ID"
}

wait_for_instance() {
  echo "Waiting for instance to be running..."
  aws ec2 wait instance-running --instance-ids $INSTANCE_ID
  echo "Instance $INSTANCE_ID is running"
}

get_public_ip() {
  echo "Retrieving public IP..."
  PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
  echo "Public IP: $PUBLIC_IP"
}

customize_instance() {
  echo "Applying configuration to instance..."
  ssh -o StrictHostKeyChecking=no -i $TEMP_KEY_PATH ec2-user@$PUBLIC_IP <<EOF
sudo yum update -y
sudo yum install awscli terraform terragrunt
EOF
  echo "Configuration complete"
}

create_ami() {
  echo "Creating AMI..."
  AMI_ID=$(aws ec2 create-image \
    --instance-id $INSTANCE_ID \
    --name $AMI_NAME \
    --no-reboot \
    --query 'ImageId' \
    --output text)
  echo "AMI creation started with ID: $AMI_ID"
}

wait_for_ami() {
  echo "Waiting for AMI to become available..."
  aws ec2 wait image-available --image-ids $AMI_ID
  echo "AMI $AMI_ID is available"
}

terminate_instance() {
  echo "Terminating instance..."
  aws ec2 terminate-instances --instance-ids $INSTANCE_ID
  echo "Instance $INSTANCE_ID terminated"
}

main() {
  create_key_pair
  create_security_group
  launch_instance
  wait_for_instance
#  get_public_ip
#  customize_instance
#  create_ami
#  wait_for_ami
  cleanup
  terminate_instance
  echo "AMI: $AMI_ID has been created and instance terminated"
}

main
