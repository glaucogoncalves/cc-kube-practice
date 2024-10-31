# **Kubernetes Cluster no AWS EC2**

Esta prática foi elaborada como um exercício da disciplina [Computação em Nuvem](https://github.com/glaucogoncalves/cc) ofertada no âmbito do PPGEE/UFPA.

A atividade trabalha a configuração e implantação de um cluster Kubernetes na AWS usando instâncias EC2, bem como a implantação de uma aplicação React/MongoDB, como exemplo. A configuração envolve a criação da infraestrutura na AWS, instalação do Kubernetes e a implantação da aplicação.

## **Pré-requisitos**

- Conta AWS ativa.
- **Chave PEM** (arquivo `.pem`) gerada durante a criação das instâncias EC2.
- Familiaridade com SSH e comandos de shell no linux.

---

## **1. Criando e Configurando a Infraestrutura no AWS**



### 1.1 Criando uma VPC Personalizada

Nesta etapa, criaremos uma VPC (Virtual Private Cloud) personalizada para isolar nossa infraestrutura e ter um melhor controle sobre a rede.

1. Acesse o **Console AWS**.
2. Vá para **VPC > Your VPCs**.
3. Clique em **Create VPC**.
4. Defina os seguintes parâmetros:
   - **Name tag**: `KubernetesVPC`
   - **IPv4 CIDR block**: `10.0.0.0/16`
   - **Tenancy**: `Default`
5. Clique em **Create**.

#### Criando Sub-redes:

1. Vá para **Subnets** e clique em **Create subnet**.
2. Crie duas sub-redes em diferentes zonas de disponibilidade:

   - **Subnet 1**:
     - **Name tag**: `PublicSubnet1`
     - **VPC**: Selecione `KubernetesVPC`
     - **Availability Zone**: Escolha uma zona (por exemplo, `us-east-1a`)
     - **IPv4 CIDR block**: `10.0.1.0/24`
   
   - **Subnet 2**:
     - **Name tag**: `PublicSubnet2`
     - **VPC**: Selecione `KubernetesVPC`
     - **Availability Zone**: Escolha uma outra zona (por exemplo, `us-east-1b`)
     - **IPv4 CIDR block**: `10.0.2.0/24`

3. Clique em **Create subnet**.

#### Criando um Internet Gateway:

1. Vá para **Internet Gateways** e clique em **Create internet gateway**.
2. Defina os seguintes parâmetros:
   - **Name tag**: `KubernetesIGW`
3. Clique em **Create internet gateway**.
4. Após a criação, selecione o **Internet Gateway** e clique em **Actions > Attach to VPC**.
5. Selecione a **KubernetesVPC** e clique em **Attach internet gateway**.

#### Configurando a Tabela de Rotas:

1. Vá para **Route Tables** e clique em **Create Router Table**..
2. Defina os seguintes parâmetros:
   - **Name**: `KubernetesRouterTable`
   - **VPC**: Selecione `KubernetesVPC`
3. Clique em **Edit routes**.
4. Adicione uma nova rota:
   - **Destination**: `0.0.0.0/0`
   - **Target**: Selecione **Internet Gateway** e na caixa abaixo selecione **KubernetesIGW**.
5. Salve as alterações.

#### Associando as Sub-redes à Tabela de Rotas:

1. Selecione a sub-rede **PublicSubnet1**
2. Em **Actions** selecione **Edit router table associations**
3. Em **Router Table ID** selecione **KubernetesRouterTable**.
4. Salve as alterações.
5. Repita os passos acima para a **PublicSubnet2**.

### 1.2 Criando Grupos de Segurança

Nesta primeira etapa criaremos duas Virtual Private Cloud (VPC) na AWS, as quais permitirão a criação de uma rede isolada entre as intâncias que criaremos posteriormente.

1. **Acesse o Console AWS** e vá para **VPC > Security Groups**.
2. Crie dois grupos de segurança **Control Plane Security Group**, associando-os à VPC **KubernetesVPC** e configurando suas **inbound rules** como abaixo:
   - **Control Plane Security Group**:
     - SSH (porta **22**): `0.0.0.0/0`
     - TCP (porta **6443**): `0.0.0.0/0`
     - TCP (portas **2379-2380**, **10250-10259**): CIDR da VPC
     - TCP (porta **30000**): frontend `0.0.0.0/0`
     - TCP (porta **31559**): backend `0.0.0.0/0`
     - TCP (porta **6784**): WeaveNet `172.31.0.0/16`
     - UDP (porta **6783-6784**): WeaveNet `172.31.0.0/16`
   - **Worker Security Group**:
     - SSH (porta **22**): `0.0.0.0/0`
     - TCP (porta **10250**): CIDR da VPC
     - TCP (portas **30000-32767**): `0.0.0.0/0`
     - TCP (porta **30000**): frontend `0.0.0.0/0`
     - TCP (porta **31559**): backend `0.0.0.0/0`
     - TCP (porta **6784**): WeaveNet `172.31.0.0/16`
     - UDP (porta **6783-6784**): WeaveNet `172.31.0.0/16`
3. **Defina a outbound rule tanto na vpc do control plane quanto na worker**:
   - All traffic `0.0.0.0/0`

### 1.3 Criando Instâncias EC2

1. **Crie 3 instâncias EC2**: 1 Control Plane e 2 Workers. Selecione as opções abaixo:
   - Control Plane: `t2.medium` (Ubuntu 22.04).
   - Workers: `t2.large` (Ubuntu 22.04).
   - **Anexe a VPC criada** para cada instância (nas configurações de rede clique em **Edit**)
   - **Anexe a Sub-rede criada** para cada instância.
   - **Anexe o grupo de segurança apropriado** para cada instância.
   - Marque a opção **Automatic Public IP**.
   - **Gere ou selecione uma chave SSH** para acessar as instâncias.

### 1.4 Conectando-se via SSH

Certifique-se de que as permissões da chave .pem estão configuradas corretamente:

```bash
chmod 400 /caminho/para/sua-chave.pem
```

Para conectar-se a uma instância EC2 via SSH:

```bash
ssh -i /caminho/para/sua-chave.pem ubuntu@<IP-PUBLICO-DA-EC2>
```

## **2. Instalando o Kubernetes**

### 2.1 Preparando o Ambiente
Nesta seção, vamos configurar o ambiente nas máquinas (Control Plane e Workers) para que todas se reconheçam mutuamente através de nomes de host amigáveis, em vez de endereços IP. Isso simplifica a comunicação entre os nós no cluster Kubernetes, especialmente quando configuramos as Workers para se conectarem ao Control Plane.

1. Clone o Repositório

Primeiro, **clone este repositório** em cada uma das VMs criadas (Control Plane e Workers) para garantir que todos os arquivos e configurações necessárias estejam acessíveis em todos os nós.

```bash
git clone https://github.com/glaucogoncalves/cc-kube-practice.git
```

2. Adicione o Mapeamento de IP para Nomes de Host

Em cada VM, precisamos atualizar o arquivo `/etc/hosts` para mapear os IPs internos para nomes de host amigáveis (control-plane, worker1 e worker2). Este mapeamento permite que os nós se comuniquem usando esses nomes em vez de endereços IP, o que é útil para simplificar a configuração e permitir futuras mudanças de IP sem alterar as configurações.

Para fazer isso:

Edite o arquivo de hosts em cada máquina:

```bash
sudo vim /etc/hosts
```
Adicione o mapeamento de IP para cada nome de host.

No arquivo `/etc/hosts`, adicione linhas semelhantes a estas (substituindo `<IP_CONTROL_PLANE>`, `<IP_WORKER1>`, e `<IP_WORKER2>` pelos IPs internos das suas instâncias):

```plaintext
<IP_CONTROL_PLANE> control-plane
<IP_WORKER1> worker1
<IP_WORKER2> worker2
```
Exemplo:
```plaintext
10.0.0.1 control-plane
10.0.0.2 worker1
10.0.0.3 worker2
```
Essa configuração deve ser feita em todas as três máquinas para que todas reconheçam o nome de host das demais.

3. Configurando o Nome do Host para Cada Máquina

Defina o nome do host de cada VM para um nome descritivo (control-plane, worker1 e worker2) para facilitar a identificação das máquinas e ajudar na organização do cluster.

No terminal, execute o comando correspondente ao nome de host da máquina:

### No Control Plane:

```bash

sudo hostnamectl set-hostname control-plane
```
### No Worker 1:
```bash
sudo hostnamectl set-hostname worker1
```
### No Worker 2:
```bash
sudo hostnamectl set-hostname worker2
```
Desconecte e reconecte o SSH após a alteração para ver o novo nome do host refletido no terminal.

4. Configurações Básicas em Todas as Instâncias

Execute os seguintes comandos em todas as instâncias (Control Plane e Workers) para aplicar configurações básicas e preparar o ambiente para o Kubernetes.

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https curl
```

Esses comandos garantirão que o sistema esteja atualizado e que o (HTTPS) esteja configurado, o que é necessário para instalar componentes adicionais, como kubeadm, kubelet e kubectl no próximo passo.

Execute os seguintes comandos em todas as instâncias EC2 (Control Plane e Workers):

```bash
sudo swapoff -a
sudo apt update
```

### 2.2 Instalando o containerd
Usaremos os scripts `containerd-install.sh` e `k8s-install.sh`, que estão neste repositório. Siga as instruções a seguir.

Execute o script de instalação do containerd
```bash
./containerd-install.sh
```

Depois cheque o campo **Active**, deve estar escrito "active (running)"
```bash
service containerd status
```
### Acessar o arquivo config.toml do containerd
Abra o arquivo config.toml do containerd para edição:

```bash
sudo nano /etc/containerd/config.toml
```
Dentro do arquivo, procure pela seguinte seção:

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = false
```
Alterne o valor de SystemdCgroup para true (se já estiver definido, verifique para garantir que o valor seja true):

```toml
SystemdCgroup = true
```
Salve e saia do editor:

Se estiver usando o nano, pressione CTRL + O para salvar e, em seguida, CTRL + X para sair.

2. Reiniciar o Serviço containerd
Após salvar as mudanças, reinicie o serviço containerd para aplicar as novas configurações:

```bash
sudo systemctl restart containerd
```
Para garantir que o containerd está ativo e em execução, verifique o status:

```bash
sudo systemctl status containerd
```
O status deve aparecer como "active (running)". 

### 2.3 Instalando kubelet, kubectl e kubeadm.
Execute o script de instalação do kubernetes.
```bash
./k8s-install.sh
```

Execute o comando abaixo, depois cheque o campo **Loaded**, deve estar "loaded" e o campo **Active** deve estar "dead"
```bash
service kubelet status
```

### 2.2 Inicializando o Cluster Kubernetes no Control Plane

No Control Plane, inicialize o cluster Kubernetes:

```bash
sudo kubeadm init
```

Configure o kubectl:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Verificar cluster kubernetes

```bash 
kubectl get pods -A
```

### 2.3 Conectando os Workers ao Cluster

No Control Plane, gere o comando kubeadm join:

```bash
kubeadm token create --print-join-command
```
Execute esse comando nos Workers com o prefixo `sudo` para conectá-los ao cluster.

Verificar se nodes foram conectados (rode no control plane)
```bash 
kubectl get nodes -A
```

### 2.4 Instalar o Weave Net como Plugin de Rede (CNI)
Para permitir a comunicação entre os pods no cluster, você deve configurar um plugin de rede CNI. No caso do Weave Net, siga o passo abaixo:

Execute o comando para aplicar o Weave Net como o plugin de rede:

```bash
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
```
Aguarde alguns minutos para que o Weave Net seja implementado e inicializado nos nós do cluster.

Verifique se o Weave Net está funcionando corretamente listando os pods no namespace kube-system:

```bash
kubectl get pods -n kube-system -o wide
```
Os pods weave-net devem estar no status "Running".

## **3. Implantando o MongoDB e a Aplicação React**
Instruções para Configurar e Executar o Projeto no Kubernetes

### 3.1 Aplicar os Arquivos no Cluster
Aplique os arquivos no cluster Kubernetes com os comandos abaixo:

```sh
kubectl apply -f namespaces.yaml
kubectl apply -f frontend-configmap.yaml
kubectl apply -f frontend-deployment.yaml
kubectl apply -f frontend-service.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f mongodb-deployment.yaml
kubectl apply -f mongodb-pv.yaml
kubectl apply -f mongodb-pvc.yaml
```
Esses comandos irão configurar o ConfigMap, criar o Deployment do frontend e expor o frontend através do Service.

### 3.2 Modifique o ConfigMap com o IP Público do Backend

Para saber qual a sua NodePort do serviço backend, digite:

```
kubectl get svc -n backend backend-service
```

Exemplo de saida do comando:
| Nome do Serviço    | Tipo       | IP do Cluster | IP Externo | Portas           | Idade |
|--------------------|------------|---------------|------------|------------------|-------|
| backend-service    | NodePort   | 10.98.12.247  | `<none>`   | 5000:32663/TCP   | 32m   |

- **Tipo**: `NodePort` permite o acesso ao serviço fora do cluster na porta `32663` dos nós do cluster.
- **IP do Cluster**: `10.98.12.247` é o IP interno do serviço dentro do cluster.
- **Porta**: O serviço está disponível na porta `5000` dentro do cluster e exposto externamente na porta `32663`.

O IP público é o IP da instancia EC2 que está localizado o backend.

O frontend-configmap.yaml define o URL do backend que o frontend irá acessar. Localize o arquivo frontend-configmap.yaml e atualize o IP no valor da URL para o IP público do backend do aluno.
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-configmap
  namespace: frontend
data:
  config.js: |
    window.REACT_APP_BACKEND_URL = "http://<SEU_IP_PUBLICO>:<PORTA_BACKEND>";
```
Substitua `<SEU_IP_PUBLICO>` pelo IP público onde o backend está sendo executado.
Substitua `<PORTA_BACKEND>` pela porta correta (como `31559` se estiver usando NodePort).
Salve o arquivo após fazer essa alteração.

### 3.3 Modifique o Service se Necessário
Verifique o arquivo `frontend-service.yaml` e assegure-se de que a configuração está correta para expor o frontend. No caso de estar usando NodePort, você pode modificar o número da porta externa se necessário.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: frontend
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
    - port: 3000        # Porta interna no cluster
      targetPort: 3000   # Porta onde o contêiner escuta
      nodePort: 30000    # Porta exposta no nó (pode ser ajustada)
```

Reinicie as aplicações para assegurar as mudanças.

```
kubectl rollout restart deployment frontend -n frontend
kubectl rollout restart deployment backend -n backend
kubectl rollout restart deployment coredns -n kube-system
```

## **4. Verifique a Configuração**
Após aplicar os arquivos, use os comandos abaixo para verificar se os recursos foram criados corretamente:

Verificar o ConfigMap
```sh
kubectl get configmap frontend-configmap -n frontend -o yaml
```
Certifique-se de que o config.js tem a URL correta do backend.

Verificar o Deployment
```sh
kubectl get deployment frontend -n frontend
kubectl describe deployment frontend -n frontend
```
Verifique se o Deployment está em execução e se o contêiner está pronto.

Verificar o Service
```sh
kubectl get service frontend-service -n frontend
```
Certifique-se de que o Service está expondo a aplicação na porta correta.

## **5. Acessar o Frontend**
Após a configuração, você pode acessar o frontend através do IP do nó e a porta definida no Service.

URL de Acesso: `http://<SEU_IP_PUBLICO_FRONTEND>:30000`
Certifique-se de substituir `<SEU_IP_PUBLICO_FRONTEND>` pelo IP público do nó onde o Frontend está executando.

## **6. Resumo de Alterações Necessárias**
No frontend-configmap.yaml: Altere `<SEU_IP_PUBLICO>` e `<PORTA_BACKEND>` na linha `window.REACT_APP_BACKEND_URL`.

No frontend-service.yaml (opcional): Ajuste nodePort se necessário para expor o frontend em uma porta diferente.

Pronto! Seu ambiente deve estar configurado para executar a aplicação no Kubernetes. Se tiver problemas, verifique os logs e os eventos dos recursos com o comando `kubectl describe pod -n <namespace> <nome-do-pod>` .
