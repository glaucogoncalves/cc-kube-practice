# **Kubernetes Cluster com PHP/MySQL no AWS EC2**

Este repositório contém instruções detalhadas para configurar e implantar um cluster Kubernetes no AWS usando instâncias EC2, com uma aplicação PHP/MySQL como exemplo. A configuração envolve a criação da infraestrutura, instalação do Kubernetes e a implantação dos serviços.


Para informações mais detalhadas, acesse o documento da aula
---

## **Sumário**

- [**Kubernetes Cluster com PHP/MySQL no AWS EC2**](#kubernetes-cluster-com-phpmysql-no-aws-ec2)
  - [Para informações mais detalhadas, acesse o documento da aula](#para-informações-mais-detalhadas-acesse-o-documento-da-aula)
  - [**Sumário**](#sumário)
  - [**Pré-requisitos**](#pré-requisitos)
  - [**1. Criando e Configurando a Infraestrutura no AWS**](#1-criando-e-configurando-a-infraestrutura-no-aws)
    - [1.1 Criando Grupos de Segurança](#11-criando-grupos-de-segurança)
    - [1.2 Criando Instâncias EC2](#12-criando-instâncias-ec2)
    - [1.3 Conectando-se via SSH](#13-conectando-se-via-ssh)
  - [**2. Instalando o Kubernetes**](#2-instalando-o-kubernetes)
    - [2.1 Instalando containerd](#21-instalando-containerd)
    - [Opcional](#opcional)
    - [2.2 Inicializando o Cluster Kubernetes no Control Plane](#22-inicializando-o-cluster-kubernetes-no-control-plane)
    - [2.3 Conectando os Workers ao Cluster](#23-conectando-os-workers-ao-cluster)
  - [**3. Implantando o MySQL e a Aplicação PHP**](#3-implantando-o-mysql-e-a-aplicação-php)
    - [3.1 Implantação do MySQL](#31-implantação-do-mysql)
    - [3.2 Implantação da Aplicação PHP](#32-implantação-da-aplicação-php)
  - [**4. Acessando a Aplicação**](#4-acessando-a-aplicação)
  - [**5. Troubleshooting**](#5-troubleshooting)
  - [5.1 Pod em estado Pending](#51-pod-em-estado-pending)
    - [5.2 Erro de Conexão ao MySQL](#52-erro-de-conexão-ao-mysql)
---

## **Pré-requisitos**

- Conta AWS ativa.
- **Chave PEM** (arquivo `.pem`) gerada durante a criação das instâncias EC2.
- Familiaridade com SSH e comandos de linha de comando.

---

## **1. Criando e Configurando a Infraestrutura no AWS**
### 1.1 Criando Grupos de Segurança

1. **Acesse o Console AWS** e vá para **VPC > Security Groups**.
2. **Crie dois grupos de segurança**:
   - **Control Plane Security Group**:
     - SSH (porta 22): `0.0.0.0/0`
     - TCP (porta 6443): `0.0.0.0/0`
     - TCP (portas 2379-2380, 10250-10259): CIDR da VPC
   - **Worker Security Group**:
     - SSH (porta 22): `0.0.0.0/0`
     - TCP (porta 10250): CIDR da VPC
     - TCP (portas 30000-32767): `0.0.0.0/0`
   - **Outbound rule tanto na vpc do control plane quanto na worker**:
   - All traffic `0.0.0.0/0`

### 1.2 Criando Instâncias EC2

1. **Crie 3 instâncias EC2**: 1 Control Plane e 2 Workers.
   - Control Plane: `t2.medium` (Ubuntu 22.04).
   - Workers: `t2.large` (Ubuntu 22.04).
2. **Anexe o grupo de segurança apropriado** para cada instância.
3. **Gere ou selecione uma chave SSH** para acessar as instâncias.

### 1.3 Conectando-se via SSH

Para conectar-se a uma instância EC2 via SSH:

```bash
ssh -i /caminho/para/sua-chave.pem ubuntu@<IP-PUBLICO-DA-EC2>
```

Certifique-se de que as permissões da chave .pem estão configuradas corretamente:

```bash
chmod 400 /caminho/para/sua-chave.pem
```

## **2. Instalando o Kubernetes**
### 2.1 Instalando containerd

### Opcional
Adicione o mapeamento de IP ao nome do host no arquivo de hosts de todos os três nós, e faça isso em todas as 3 máquinas

```bash 
sudo vim /etc/hosts
``` 
![alt text](image.png)

No terminal, substituiremos o ip por um nome de host amigável. Execute o comando a seguir, mas substitua control-plane por worker1 e worker2 , ao executar em terminais respectivos.

```bash
sudo hostnamectl set-hostname control-plane
```
```bash
sudo hostnamectl set-hostname worker1
```
```bash
sudo hostnamectl set-hostname worker2
```

Saia e entre novamente nas máquinas para aparecer os nomes

Execute os seguintes comandos em todas as instâncias EC2 (Control Plane e Workers):

```bash
sudo swapoff -a
sudo apt update
```

Crie os 

### 2.2 Inicializando o Cluster Kubernetes no Control Plane

No Control Plane, inicialize o cluster Kubernetes:

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```
Configure o kubectl:

```bash

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
### 2.3 Conectando os Workers ao Cluster

No Control Plane, gere o comando kubeadm join:

```bash
kubeadm token create --print-join-command
```
Execute esse comando nos Workers para conectá-los ao cluster.
## **3. Implantando o MySQL e a Aplicação PHP**
### 3.1 Implantação do MySQL

Crie o arquivo mysql-deployment.yaml:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pv-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
spec:
  ports:
    - port: 3306
  selector:
    app: mysql
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-deployment
spec:
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - image: mysql:5.7
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "password"
        - name: MYSQL_DATABASE
          value: "todo"
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-persistent-storage
        persistentVolumeClaim:
          claimName: mysql-pv-claim
```
Implante o MySQL:

```bash
kubectl apply -f mysql-deployment.yaml
```
### 3.2 Implantação da Aplicação PHP

Crie o arquivo php-deployment.yaml:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: php-service
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30589
  selector:
    app: php
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: php
  template:
    metadata:
      labels:
        app: php
    spec:
      containers:
      - image: lucasmatni01/php-todo:latest
        name: php
        ports:
        - containerPort: 80
        env:
        - name: MYSQL_HOST
          value: "mysql-service"
        - name: MYSQL_USER
          value: "root"
        - name: MYSQL_PASSWORD
          value: "password"
        - name: MYSQL_DATABASE
          value: "todo"
```
Implante a aplicação PHP:

```bash
kubectl apply -f php-deployment.yaml
```
## **4. Acessando a Aplicação**

    Obtenha o IP público da sua instância EC2 (Worker).
    No navegador, acesse a aplicação via NodePort:

``` vbnet

http://<IP-PUBLICO-DO-WORKER>:30589
```

## **5. Troubleshooting**
## 5.1 Pod em estado Pending

    Causa: Pode ser um problema com volumes persistentes ou falta de recursos no nó.
    Solução: Verifique o status do pod com:

```bash
kubectl describe pod <nome-do-pod>
```

### 5.2 Erro de Conexão ao MySQL

    Solução: Verifique se o MySQL está rodando e se as credenciais estão corretas.