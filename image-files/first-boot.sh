#! /bin/sh

# set variables
URL="http://metadata/computeMetadata/v1/instance/attributes/"
HEADER="X-Google-Metadata-Request: True"

wget -P /tmp/ https://raw.githubusercontent.com/karmab/kubevirt-autodeployer/master/versions.sh
source /tmp/versions.sh

wget -O - $URL/k8s_version --header="$HEADER" > /tmp/x && K8S=`cat /tmp/x`
if [ "$?" == "0" ] ; then 
  K8S=`cat /tmp/x`
  if [ "$K8S" == 'latest' ] ; then
    K8S=`curl -s https://api.github.com/repos/kubernetes/kubernetes/releases/latest| jq -r .tag_name | sed 's/v//'`
  fi
  if [ "`echo $K8S | tr -cd '.' | wc -c`" == "1" ] ; then
    K8S=$K8S.0
  fi

fi

wget -O - $URL/flannel_version --header="$HEADER" > /tmp/x && FLANNEL=`cat /tmp/x`
if [ "$?" == "0" ] ; then 
  FLANNEL=`cat /tmp/x`
  if [ "FLANNEL" == 'latest' ] ; then
    FLANNED=`curl -s https://api.github.com/repos/coreos/flannel/releases/latest| jq -r .tag_name`
  fi
fi

wget -O - $URL/kubevirt_version --header="$HEADER" > /tmp/x 
if [ "$?" == "0" ] ; then 
  KUBEVIRT=`cat /tmp/x`
  if [ "$KUBEVIRT" == 'latest' ] ; then
    KUBEVIRT=`curl -s https://api.github.com/repos/kubevirt/kubevirt/releases/latest| jq -r .tag_name`
  fi
fi

wget -O - $URL/cdi_version --header="$HEADER" > /tmp/x
if [ "$?" == "0" ] ; then 
  CDI=`cat /tmp/x`
  if [ "CDI" == 'latest' ] ; then
    CDI=`curl -s https://api.github.com/repos/kubevirt/containerized-data-importer/releases/latest| jq -r .tag_name`
  fi
fi

wget -O - $URL/kubevirt_ui_version --header="$HEADER" > /tmp/x
if [ "$?" == "0" ] ; then 
  KUBEVIRT_UI=`cat /tmp/x`
fi

# make sure we use a weave network that doesnt conflict
# for num in `seq 30 50` ; do
# ip r | grep -q 172.$num
# if [ "$?" != "0" ] ; then
#  WEAVENETWORK="172.30/172.$num/24"
#  break
# fi
# done

# deploy kubernetes
echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.d/99-sysctl.conf
sysctl -p
setenforce 0
sed -i "s/SELINUX=enforcing/SELINUX=permissive/" /etc/selinux/config
yum install -y docker kubelet-${K8S} kubectl-${K8S} kubeadm-${K8S}
sed -i "s/--selinux-enabled //" /etc/sysconfig/docker
systemctl enable docker && systemctl start docker
systemctl enable kubelet && systemctl start kubelet
CIDR="10.244.0.0/16"
kubeadm init --pod-network-cidr=${CIDR}
cp /etc/kubernetes/admin.conf /root/
chown root:root /root/admin.conf
export KUBECONFIG=/root/admin.conf
echo "export KUBECONFIG=/root/admin.conf" >>/root/.bashrc
kubectl taint nodes --all node-role.kubernetes.io/master-

# deploy flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/${FLANNEL}/Documentation/kube-flannel.yml
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# deploy dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/alternative/kubernetes-dashboard.yaml
kubectl create clusterrolebinding kubernetes-dashboard-head --clusterrole=cluster-admin --user=system:serviceaccount:kube-system:kubernetes-dashboard

# deploy kubevirt 
yum -y install xorg-x11-xauth virt-viewer wget
kubectl create ns kubevirt
grep -q vmx /proc/cpuinfo || oc create configmap -n kubevirt kubevirt-config
grep -q vmx /proc/cpuinfo || oc create configmap -n kube-system kubevirt-config
if [ "$KUBEVIRT" == 'master' ] || [ "$KUBEVIRT" -eq "$KUBEVIRT" ] ; then
  kubectl create ns kubevirt
  yum -y install git make
  cd /root
  git clone https://github.com/kubevirt/kubevirt
  cd kubevirt
  export KUBEVIRT_PROVIDER=k8s-$K8S
  export KUBEVIRT_PROVIDER=external
  if [ "$KUBEVIRT" -eq "$KUBEVIRT" ] ; then
    git fetch origin refs/pull/$KUBEVIRT/head:pull_$KUBEVIRT
    git checkout pull_$KUBEVIRT
  fi
  source hack/config-default.sh
  sed -i "s/\$docker_prefix/kubevirt/" hack/*sh
  sed -i "s/\${docker_prefix}/kubevirt/" hack/*sh
  make cluster-up
  make docker manifests
  sed -i "s/latest/devel/" _out/manifests/release/kubevirt.yaml
  kubectl create -f _out/manifests/release/kubevirt.yaml
else
  wget https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT}/kubevirt.yaml
  kubectl create -f kubevirt.yaml --validate=false
  wget https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT}/virtctl-${KUBEVIRT}-linux-amd64
  mv virtctl-${KUBEVIRT}-linux-amd64 /usr/bin/virtctl
  chmod u+x /usr/bin/virtctl
fi

# deploy cdi
kubectl create ns golden
kubectl create clusterrolebinding cdi --clusterrole=edit --user=system:serviceaccount:golden:default
kubectl create clusterrolebinding cdi-apiserver --clusterrole=cluster-admin --user=system:serviceaccount:golden:cdi-apiserver
wget https://github.com/kubevirt/containerized-data-importer/releases/download/${CDI}/cdi-controller.yaml
sed -i "s/namespace:.*/namespace: golden/" cdi-controller.yaml
kubectl apply -f cdi-controller.yaml -n golden
kubectl expose svc cdi-uploadproxy -n golden

# deploy kubevirt ui
kubectl create namespace kweb-ui
kubectl create clusterrolebinding kweb-ui --clusterrole=edit --user=system:serviceaccount:kweb-ui:default
sed -i "s/KUBEVIRT_UI/$KUBEVIRT_UI/" /root/ui.yml
kubectl apply -f /root/ui.yml -n kweb-ui

# set default context
kubectl config set-context `kubectl config current-context` --namespace=default

# generate motd
sed -i "s/K8S/$K8S/" /etc/motd
sed -i "s/FLANNEL/$FLANNEL/" /etc/motd
sed -i "s/KUBEVIRT/$KUBEVIRT/" /etc/motd
sed -i "s/UI/${KUBEVIRT_UI}/" /etc/motd
sed -i "s/CDI/$CDI/" /etc/motd

# disable the service so it only runs the first time the VM boots
sudo chkconfig kubevirt-installer off
