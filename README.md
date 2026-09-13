# Modern Kubernetes Platform Lab

This repository contains a full-stack, enterprise-grade Kubernetes lab built on Azure. It transitions from imperative scripts to a modern **Terraform ➔ Kubespray ➔ GitOps** pipeline.

## 🏗️ Architecture

```text
Internet
    |
Azure Load Balancer (NodePort: 80/443)
    |
NGINX Ingress Controller
    |
+---------------------------------------------------+
| ArgoCD (GitOps Engine)                            |
| Prometheus (Monitoring)                           |
| Grafana (Dashboards)                              |
+---------------------------------------------------+
```
* **Infrastructure:** Terraform (Azure VMs, Network, Load Balancer)
* **Cluster Lifecycle:** Kubespray (Ansible)
* **Application Delivery:** ArgoCD (GitOps)

---

## 🚀 Phase 1: Infrastructure Provisioning (Terraform)

Terraform provisions the Azure resources and automatically generates the dynamic `inventory.ini` file required by Kubespray.

**1. Initialize and Apply:**
```bash
cd terraform
terraform init
terraform apply
```

**2. Copy the Inventory:**
Terraform will output a generated `inventory.ini`. Transfer this to your jumpbox:
```bash
scp ./inventory.ini debian@<JUMPBOX_PUBLIC_IP>:~/
```

---

## ⚙️ Phase 2: Cluster Deployment (Kubespray)

Log into your jumpbox to orchestrate the cluster installation. Kubespray will SSH into your private nodes and build Kubernetes.

**1. SSH into the Jumpbox:**
```bash
ssh debian@<JUMPBOX_PUBLIC_IP>
```

**2. Prepare Kubespray:**
```bash
sudo apt-get update && sudo apt-get install -y git python3 python3-pip python3-venv
git clone [https://github.com/kubernetes-sigs/kubespray.git](https://github.com/kubernetes-sigs/kubespray.git)
cd kubespray
git checkout master
git pull origin master
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**3. Stage the Configuration:**
```bash
cp -rfp inventory/sample inventory/mycluster
cp ~/inventory.ini inventory/mycluster/inventory.ini
```

**4. Build the Cluster:**
```bash
ansible-playbook -i inventory/mycluster/inventory.ini --become --become-user=root cluster.yml
```
*(Grab a coffee, this takes 10-15 minutes).*

**5. Configure `kubectl` on the Jumpbox:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

mkdir -p ~/.kube
sudo scp root@10.240.0.11:/etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
sed -i 's/127.0.0.1/10.240.0.11/g' ~/.kube/config

# quality-of-life: k alias + completion
echo "alias k=kubectl" >> ~/.bashrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc

kubectl get nodes
```

---

## 🔄 Phase 3: GitOps Bootstrap (ArgoCD)

**1. Create Your GitOps Repository**
Push your `gitops/` folder (containing your ArgoCD apps) to a public GitHub repository. Ensure `kube-prometheus-stack.yaml` has `ServerSideApply=true` and memory limits tuned for the worker nodes.

**2. Install ArgoCD:**
Run this on your jumpbox to install the GitOps controller:
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f [https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml](https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml)
```

**3. Apply the Root App:**
Update the `repoURL` in your local `root-app.yaml` to point to your new GitHub repository, then apply it:
```bash
kubectl apply -f root-app.yaml
```

ArgoCD will now automatically sync your cluster, installing NGINX Ingress, Local Path Provisioner, and the Prometheus/Grafana stack!

---

## 🌐 Accessing the Dashboards

Once ArgoCD finishes syncing, your apps are exposed via the Azure Load Balancer.

1. Get your Load Balancer IP (run this locally or check Azure Portal):
   ```bash
   az network public-ip show -g kubeadm-lab-rg -n kubeadm-lb-pip --query ipAddress -o tsv
   ```
2. Add the routing to your local Windows `C:\Windows\System32\drivers\etc\hosts` file:
   ```text
   <LOAD_BALANCER_IP> grafana.lab.local
   <LOAD_BALANCER_IP> prometheus.lab.local
   <LOAD_BALANCER_IP> argocd.lab.local
   ```
3. Open your browser:
   * **Grafana:** `http://grafana.lab.local` (Default login: `admin` / `admin`)
   * **Prometheus:** `http://prometheus.lab.local`
   * **ArgoCD:** `https://argocd.lab.local`