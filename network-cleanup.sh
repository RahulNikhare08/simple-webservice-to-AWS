#!/bin/bash
set -e

echo "🌐 Cleaning up networking components..."

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=hello-fargate-vpc" --query 'Vpcs[0].VpcId' --output text --region us-east-1 2>/dev/null || echo "None")

if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
    echo "Found VPC: $VPC_ID"
    
    # Delete NAT Gateways first
    echo "Deleting NAT gateways..."
    NAT_IDS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[?State==`available`].NatGatewayId' --output text --region us-east-1)
    for NAT_ID in $NAT_IDS; do
        if [ "$NAT_ID" != "" ]; then
            echo "Deleting NAT Gateway: $NAT_ID"
            aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID --region us-east-1
        fi
    done
    
    # Wait for NAT gateways to delete
    if [ "$NAT_IDS" != "" ]; then
        echo "Waiting for NAT gateways to delete..."
        sleep 60
    fi
    
    # Release Elastic IPs
    echo "Releasing Elastic IPs..."
    EIP_ALLOCS=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=hello-fargate-nat-eip-*" --query 'Addresses[].AllocationId' --output text --region us-east-1)
    for EIP_ID in $EIP_ALLOCS; do
        if [ "$EIP_ID" != "" ]; then
            echo "Releasing EIP: $EIP_ID"
            aws ec2 release-address --allocation-id $EIP_ID --region us-east-1 || true
        fi
    done
    
    # Delete subnets
    echo "Deleting subnets..."
    SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text --region us-east-1)
    for SUBNET_ID in $SUBNET_IDS; do
        if [ "$SUBNET_ID" != "" ]; then
            echo "Deleting subnet: $SUBNET_ID"
            aws ec2 delete-subnet --subnet-id $SUBNET_ID --region us-east-1 || true
        fi
    done
    
    # Delete route tables (except main)
    echo "Deleting route tables..."
    RT_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text --region us-east-1)
    for RT_ID in $RT_IDS; do
        if [ "$RT_ID" != "" ]; then
            echo "Deleting route table: $RT_ID"
            aws ec2 delete-route-table --route-table-id $RT_ID --region us-east-1 || true
        fi
    done
    
    # Delete security groups (except default)
    echo "Deleting security groups..."
    SG_IDS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text --region us-east-1)
    for SG_ID in $SG_IDS; do
        if [ "$SG_ID" != "" ]; then
            echo "Deleting security group: $SG_ID"
            aws ec2 delete-security-group --group-id $SG_ID --region us-east-1 || true
        fi
    done
    
    # Delete internet gateway
    echo "Deleting internet gateway..."
    IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text --region us-east-1)
    if [ "$IGW_ID" != "None" ] && [ "$IGW_ID" != "" ]; then
        echo "Detaching and deleting IGW: $IGW_ID"
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region us-east-1 || true
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region us-east-1 || true
    fi
    
    # Delete VPC
    echo "Deleting VPC..."
    aws ec2 delete-vpc --vpc-id $VPC_ID --region us-east-1 || true
    
    echo "✅ Networking cleanup completed!"
else
    echo "ℹ️ No VPC found with name hello-fargate-vpc"
fi
