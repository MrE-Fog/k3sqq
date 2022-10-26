#!/bin/bash

ARCH=$(uname -m); if [ $ARCH = "aarch64" ]; then ARCH="arm64"; fi
AWS_METADATA_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
AZ=$(curl -H "X-aws-ec2-metadata-token: $AWS_METADATA_TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $AWS_METADATA_TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
DB_PASS=$(aws --region "$REGION" ssm get-parameter --with-decryption --name /"$PREFIX"-"$SUFFIX"/DB_PASS --query Parameter.Value --output text)
K3S_TOKEN=$(aws --region "$REGION" ssm get-parameter --with-decryption --name /"$PREFIX"-"$SUFFIX"/K3S_TOKEN --query Parameter.Value --output text)
K3S_BIN_PATH="/usr/local/bin"
K3S_BIN_FILE="k3s"
K3S_TAR_PATH="/var/lib/rancher/k3s/agent/images"
K3S_TAR_FILE="k3s-airgap-images"
K3S_INSTALL_PATH="/usr/local/bin"
K3S_INSTALL_FILE="install.sh"
HELM_BIN_FILE="helm"
CHARTS_PATH="/opt/charts"
K3S_DATASTORE_ENDPOINT="postgres://$PREFIX$SUFFIX:$DB_PASS@$DB_ENDPOINT/$PREFIX$SUFFIX"
INSTALL_K3S_SKIP_DOWNLOAD="true"
export ARCH AWS_METADATA_TOKEN AZ INSTANCE_ID DB_PASS K3S_TOKEN K3S_BIN_PATH K3S_BIN_FILE K3S_TAR_PATH K3S_TAR_FILE K3S_INSTALL_PATH K3S_INSTALL_FILE K3S_DATASTORE_ENDPOINT INSTALL_K3S_SKIP_DOWNLOAD HELM_BIN_FILE CHARTS_PATH

# k3s binary
if [ -f "$K3S_BIN_PATH/$K3S_BIN_FILE" ]; then
    echo "bin exists, skipping"
else
    aws --region "$REGION" s3 cp s3://"$PREFIX"-"$SUFFIX"-private/data/downloads/k3s/"$K3S_BIN_FILE"-"$ARCH" "$K3S_BIN_PATH"/"$K3S_BIN_FILE"
    chmod +x "$K3S_BIN_PATH"/"$K3S_BIN_FILE"
fi

# k3s directories
mkdir -p /etc/rancher/k3s /var/lib/rancher/k3s/agent/images
chmod 750 /etc/rancher/k3s /var/lib/rancher/k3s/agent/images

# nameserver to k3s
grep nameserver /etc/resolv.conf > /etc/rancher/k3s/resolv.conf

# k3s iptables
yum -y remove iptables
for i in iptables iptables-apply iptables-legacy iptables-legacy-restore iptables-legacy-save iptables-restore iptables-save; do 
  ln -s /var/lib/rancher/k3s/data/current/bin/aux/"$i" /sbin/"$i"
done

# k3s tar
if [ -f "$K3S_TAR_PATH/$K3S_TAR_FILE".tar ]; then
    echo "tar exists, skipping"
else
    aws --region "$REGION" s3 cp s3://"$PREFIX"-"$SUFFIX"-private/data/downloads/k3s/"$K3S_TAR_FILE"-"$ARCH".tar "$K3S_TAR_PATH"/"$K3S_TAR_FILE".tar --quiet
fi

# k3s install
if [ -f "$K3S_INSTALL_PATH/$K3S_INSTALL_FILE" ]; then
    echo "bin exists, skipping"
else
    aws --region "$REGION" s3 cp s3://"$PREFIX"-"$SUFFIX"-private/scripts/"$K3S_INSTALL_FILE" "$K3S_INSTALL_PATH"/"$K3S_INSTALL_FILE" --quiet
    chmod +x "$K3S_INSTALL_PATH"/"$K3S_INSTALL_FILE"
fi

# install k3s
if [ "$K3S_NODEGROUP" == "control-plane" ]; then
    # chart(s)
    mkdir -p "$CHARTS_PATH"
    aws --region "$REGION" s3 sync s3://"$PREFIX"-"$SUFFIX"-private/data/downloads/charts/ "$CHARTS_PATH"/ --quiet
    bash control-plane.sh
else
    bash worker.sh
fi