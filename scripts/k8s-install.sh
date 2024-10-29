echo "Torne o script executável usando chmod u+x FILE_NAME.sh"

sudo apt-get update

sudo apt-get install -y apt-transport-https ca-certificates curl gpg


curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

echo "Instalando kubeadm, kubelet e kubectl"
sudo apt-get install -y kubelet kubeadm kubectl

echo "Corrigir versão para evitar atualizações"
sudo apt-mark hold kubelet kubeadm kubectl