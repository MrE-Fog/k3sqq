#!/bin/bash

# run by control-plane.sh

mkdir -p "$CHARTS_PATH"

# charts from tf -> getk3s lambda -> s3
/usr/local/bin/aws --region "$REGION" s3 sync s3://"$PREFIX"-"$SUFFIX"-private/data/downloads/charts/ "$CHARTS_PATH"/ --quiet

# charts from tf -> ../charts/ -> s3 -> ssm (scripts/charts/*.zip)
cd charts/
for CHART_ZIP in *.zip; do
    CHART_NAME=$(echo $CHART_ZIP | awk -F'.' '{print $1}')
    rm -rf "$CHARTS_PATH"/"$CHART_NAME"
    unzip $CHART_ZIP -d "$CHARTS_PATH"/"$CHART_NAME"
done
cd ../

# cilium-secret
until helm --kube-apiserver https://localhost:6443 --kubeconfig /etc/rancher/k3s/k3s.yaml upgrade --install \
    --namespace kube-system cilium-secret \
    "$CHARTS_PATH"/cilium-secret
do
  echo "Installing chart.."
  sleep 1
done

# cilium
tee "$CHARTS_PATH"/cilium.yaml >/dev/null <<EOM

certgen:
  image:
    repository: $ECR_URI_PREFIX-quay/cilium/certgen
    tag: "v0.1.8@sha256:4a456552a5f192992a6edcec2febb1c54870d665173a33dc7d876129b199ddbd"

encryption:
  enabled: true
  type: ipsec
  secretName: cilium-ipsec-keys

hubble:
  enabled: false

image:
  repository: $ECR_URI_PREFIX-quay/cilium/cilium
  tag: "v1.13.0-rc4"

ipam:
  mode: "cluster-pool"
  operator:
    clusterPoolIPv4PodCIDR: "$POD_CIDR"
    clusterPoolIPv4MaskSize: 24

operator:
  enabled: true
  image:
    repository: $ECR_URI_PREFIX-quay/cilium/operator
    tag: "v1.13.0-rc4"
  replicas: 1

EOM

until helm --kube-apiserver https://localhost:6443 --kubeconfig /etc/rancher/k3s/k3s.yaml upgrade --install \
    --namespace kube-system cilium -f "$CHARTS_PATH"/cilium.yaml \
    "$CHARTS_PATH"/cilium.tgz
do
  echo "Installing chart.."
  sleep 1
done

# cilium-mgmt
tee "$CHARTS_PATH"/cilium-mgmt.yaml >/dev/null <<EOM

vpc_cidr: $VPC_CIDR

EOM

until helm --kube-apiserver https://localhost:6443 --kubeconfig /etc/rancher/k3s/k3s.yaml upgrade --install \
    --create-namespace \
    --namespace kube-system cilium-mgmt -f "$CHARTS_PATH"/cilium-mgmt.yaml \
    "$CHARTS_PATH"/cilium-mgmt
do
  echo "Installing chart.."
  sleep 1
done

# aws-cloud-controller-manager
tee "$CHARTS_PATH"/aws-cloud-controller-manager.yaml >/dev/null <<EOM

namespace: "kube-system"
args:
  - --v=2
  - --cloud-provider=aws
  - --allocate-node-cidrs=false
  - --configure-cloud-routes=false
  - --cluster-cidr=$POD_CIDR
  - --cluster-name=$PREFIX-$SUFFIX

image:
    repository: $ECR_URI_PREFIX-codebuild/registry.k8s.io/provider-aws/cloud-controller-manager
    tag: v1.25.1
nameOverride: "aws-cloud-controller-manager"
nodeSelector:
  node-role.kubernetes.io/control-plane: "true"

clusterRoleRules:
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
  - patch
  - update
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - '*'
- apiGroups:
  - ""
  resources:
  - nodes/status
  verbs:
  - patch
- apiGroups:
  - ""
  resources:
  - services
  verbs:
  - list
  - patch
  - update
  - watch
- apiGroups:
  - ""
  resources:
  - services/status
  verbs:
  - list
  - patch
  - update
  - watch
- apiGroups:
  - ""
  resources:
  - serviceaccounts
  verbs:
  - create
- apiGroups:
  - ""
  resources:
  - persistentvolumes
  verbs:
  - get
  - list
  - update
  - watch
- apiGroups:
  - ""
  resources:
  - endpoints
  verbs:
  - create
  - get
  - list
  - watch
  - update
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - create
  - get
  - list
  - watch
  - update
- apiGroups:
  - ""
  resources:
  - serviceaccounts/token
  verbs:
  - create

resources:
  requests:
    cpu: 200m

tolerations:
- key: node.cloudprovider.kubernetes.io/uninitialized
  value: "true"
  effect: NoSchedule
- key: node-role.kubernetes.io/master
  effect: NoSchedule
- key: node-role.kubernetes.io/control-plane
  effect: NoSchedule

dnsPolicy: Default
clusterRoleName : system:cloud-controller-manager
roleBindingName: cloud-controller-manager:apiserver-authentication-reader
serviceAccountName: cloud-controller-manager
roleName: extension-apiserver-authentication-reader

EOM

helm --kube-apiserver https://localhost:6443 --kubeconfig /etc/rancher/k3s/k3s.yaml upgrade --install \
    --namespace kube-system aws-cloud-controller-manager -f "$CHARTS_PATH"/aws-cloud-controller-manager.yaml \
    "$CHARTS_PATH"/aws-cloud-controller-manager.tgz

# aws-ebs-csi-driver
tee "$CHARTS_PATH"/aws-ebs-csi-driver.yaml >/dev/null <<EOM

image:
  repository: $ECR_URI_PREFIX-ecr/ebs-csi-driver/aws-ebs-csi-driver

sidecars:
  provisioner:
    image:
      repository: $ECR_URI_PREFIX-codebuild/k8s.gcr.io/sig-storage/csi-provisioner
      tag: "v3.1.0"
  attacher:
    image:
      repository: $ECR_URI_PREFIX-codebuild/k8s.gcr.io/sig-storage/csi-attacher
      tag: "v3.4.0"
  snapshotter:
    image:
      repository: $ECR_URI_PREFIX-codebuild/k8s.gcr.io/sig-storage/csi-snapshotter
      tag: "v6.0.1"
  livenessProbe:
    image:
      repository: $ECR_URI_PREFIX-codebuild/k8s.gcr.io/sig-storage/livenessprobe
      tag: "v2.6.0"
  resizer:
    image:
      repository: $ECR_URI_PREFIX-codebuild/k8s.gcr.io/sig-storage/csi-resizer
      tag: "v1.4.0"
  nodeDriverRegistrar:
    image:
      repository: $ECR_URI_PREFIX-codebuild/k8s.gcr.io/sig-storage/csi-node-driver-registrar
      tag: "v2.5.1"

controller:
  env:
  - name: AWS_DEFAULT_REGION
    value: "$REGION"
  - name: AWS_REGION
    value: "$REGION"
  - name: AWS_ROLE_ARN
    value: "arn:aws:iam::$ACCOUNT:role/$PREFIX-$SUFFIX-aws-ebs-csi-driver"
  - name: AWS_WEB_IDENTITY_TOKEN_FILE
    value: "/var/run/secrets/kubernetes.io/serviceaccount/token"
  - name: AWS_STS_REGIONAL_ENDPOINTS
    value: regional

  nodeSelector:
    node-role.kubernetes.io/control-plane: "true"
  region: $REGION
  replicaCount: 1
  tolerations:
  - effect: NoSchedule
    operator: Exists

  volumes:
  - name: serviceaccount
    projected:
      sources:
      - serviceAccountToken:
          path: token
          expirationSeconds: 43200
          audience: $PREFIX-$SUFFIX
  volumeMounts:
  - mountPath: "/var/run/secrets/kubernetes.io/serviceaccount/"
    name: serviceaccount

node:
  env:
  - name: AWS_DEFAULT_REGION
    value: "$REGION"
  - name: AWS_REGION
    value: "$REGION"
  tolerations:
  - effect: NoSchedule
    operator: Exists

storageClasses:
- name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
  mountOptions:
  - tls
  parameters:
    encrypted: "true"
    kmsKeyId: "$EBS_KMS_ARN"
  reclaimPolicy: Delete
  volumeBindingMode: WaitForFirstConsumer
EOM

helm --kube-apiserver https://localhost:6443 --kubeconfig /etc/rancher/k3s/k3s.yaml upgrade --install \
    --namespace kube-system aws-ebs-csi-driver -f "$CHARTS_PATH"/aws-ebs-csi-driver.yaml \
    "$CHARTS_PATH"/aws-ebs-csi-driver.tgz

# aws-efs-csi-driver
tee "$CHARTS_PATH"/aws-efs-csi-driver.yaml >/dev/null <<EOM

controller:
  tags:
    cluster: $PREFIX-$SUFFIX
  regionalStsEndpoints: true
  nodeSelector:
    node-role.kubernetes.io/control-plane: "true"
  tolerations:
  - effect: NoSchedule
    operator: Exists

image:
  repository: $ECR_URI_PREFIX-codebuild/amazon/aws-efs-csi-driver
  tag: "v1.4.8"

sidecars:
  livenessProbe:
    image:
      repository: $ECR_URI_PREFIX-ecr/eks-distro/kubernetes-csi/livenessprobe
      tag: "v2.8.0-eks-1-24-5"
  nodeDriverRegistrar:
    image:
      repository: $ECR_URI_PREFIX-ecr/eks-distro/kubernetes-csi/node-driver-registrar
      tag: "v2.6.2-eks-1-24-5"
  csiProvisioner:
    image:
      repository: $ECR_URI_PREFIX-ecr/eks-distro/kubernetes-csi/external-provisioner
      tag: "v3.3.0-eks-1-24-5"

replicaCount: 1

storageClasses:
- name: efs
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
  mountOptions:
  - tls
  parameters:
    provisioningMode: efs-ap
    fileSystemId: "$EFS_ID"
    directoryPerms: "700"
    gidRangeStart: "1000"
    gidRangeEnd: "9000"
  reclaimPolicy: Delete
  volumeBindingMode: WaitForFirstConsumer

EOM

helm --kube-apiserver https://localhost:6443 --kubeconfig /etc/rancher/k3s/k3s.yaml upgrade --install \
    --namespace kube-system aws-efs-csi-driver -f "$CHARTS_PATH"/aws-efs-csi-driver.yaml \
    "$CHARTS_PATH"/aws-efs-csi-driver.tgz

# external-dns
tee "$CHARTS_PATH"/external-dns.yaml >/dev/null <<EOM

image:
  registry: $ECR_URI_PREFIX-codebuild
  repository: ghcr.io/zcube/bitnami-compat/external-dns
  tag: 0
aws:
  region: "$REGION"
tolerations:
- key: node-role.kubernetes.io/master
  effect: NoSchedule
- key: node-role.kubernetes.io/control-plane
  effect: NoSchedule
extraEnvVars:
- name: AWS_DEFAULT_REGION
  value: "$REGION"
- name: AWS_ROLE_ARN
  value: "arn:aws:iam::$ACCOUNT:role/$PREFIX-$SUFFIX-external-dns"
- name: AWS_WEB_IDENTITY_TOKEN_FILE
  value: "/var/run/secrets/kubernetes.io/serviceaccount/token"
- name: AWS_STS_REGIONAL_ENDPOINTS
  value: regional
nodeSelector:
  node-role.kubernetes.io/control-plane: "true"
EOM

if [ $NAT_GATEWAYS == "true" ]; then
  helm --kube-apiserver https://localhost:6443 --kubeconfig /etc/rancher/k3s/k3s.yaml upgrade --install \
      --namespace kube-system external-dns -f "$CHARTS_PATH"/external-dns.yaml \
      "$CHARTS_PATH"/external-dns.tgz
else
  echo "INFO: Skipping external-dns, NAT_GATEWAYS = $NAT_GATEWAYS"
fi
