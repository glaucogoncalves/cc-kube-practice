echo "Torne o script executável usando chmod u+x FILE_NAME.sh"

echo "Script de instalação do Containerd"
echo "Intruções de https://kubernetes.io/docs/setup/production-environment/container-runtimes/"

echo "Criando arquivo de configuração do containerd com lista de módulos necessários"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

echo "Carregando módulos do containerd"
sudo modprobe overlay
sudo modprobe br_netfilter


echo "Criando arquivo de configuração para o arquivo kubernetes-cri"
# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

echo "Aplicando parâmetros sysctl"
sudo sysctl --system


echo "Verifique se os módulos de sobreposição br_netfilter estão carregados executando os seguintes comandos:"
lsmod | grep br_netfilter
lsmod | grep overlay

echo "Verifique se as variáveis ​​de sistema net.bridge.bridge-nf-call-iptables, net.bridge.bridge-nf-call-ip6tables e net.ipv4.ip_forward estão definidas como 1 na configuração do sysctl executando o seguinte comando:"
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

echo "Lista de pacotes de atualização"
sudo apt-get update

echo "Instalando containerd"
sudo apt-get -y install containerd

echo "Criando um arquivo de configuração padrão no local padrão"
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

echo "Reiniciando conteinerd"
sudo systemctl restart containerd