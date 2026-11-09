# Laboratório de Estudos: Argo no Kubernetes (k3d)

Estrutura inicial para estudar **Argo CD** (e demais ferramentas do ecossistema Argo) localmente usando **k3d**.

## 📁 Estrutura do Repositório

- [`k3d-config.yaml`](./k3d-config.yaml): Configuração declarativa do cluster `argo-lab` (1 control-plane, 2 workers, LoadBalancer nas portas `8080` e `8443`).
- [`argocd/argocd-cmd-params-cm.yaml`](./argocd/argocd-cmd-params-cm.yaml): Configura o `argocd-server` em modo `insecure` (HTTP) para funcionar sem conflito de TLS atrás do Ingress Traefik do k3d.
- [`argocd/ingress.yaml`](./argocd/ingress.yaml): Expõe a interface do Argo CD em `http://argocd.localhost:8080`.
- [`apps/guestbook-app.yaml`](./apps/guestbook-app.yaml): Aplicação de exemplo (`Application` CRD) com Auto-Sync e Self-Heal ativados.

---

## 🚀 Como Usar

### 1. Criar o Cluster k3d
```powershell
k3d cluster create --config k3d-config.yaml
```

### 2. Instalar o Argo CD
```powershell
kubectl create namespace argocd
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aplicar configuração HTTP + Ingress para acesso direto sem port-forward
kubectl apply -f argocd/argocd-cmd-params-cm.yaml
kubectl rollout restart deployment argocd-server -n argocd
kubectl apply -f argocd/ingress.yaml
```

### 3. Acessar a Interface Web (UI)
- **URL:** [http://argocd.localhost:8080](http://argocd.localhost:8080)
- **Usuário:** `admin`
- **Obter a senha inicial (PowerShell):**
  ```powershell
  $password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
  ```

### 4. Fazer Deploy da Primeira Aplicação via GitOps
```powershell
kubectl apply -f apps/guestbook-app.yaml
```
Após aplicar, acompanhe a sincronização automática diretamente na UI em [http://argocd.localhost:8080](http://argocd.localhost:8080).

---

## 🛠️ Comandos Úteis do Dia a Dia

```powershell
# Pausar o cluster (economizar RAM/CPU sem perder dados)
k3d cluster stop argo-lab

# Iniciar o cluster novamente
k3d cluster start argo-lab

# Destruir o cluster completamente
k3d cluster delete argo-lab
```
