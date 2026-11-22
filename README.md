# Laboratório de Estudos: Argo no Kubernetes (k3d)

Estrutura para estudar **Argo CD** (e demais ferramentas do ecossistema Argo) localmente usando **k3d**, aplicando o padrão de mercado **App of Apps** (autogerenciamento via GitOps em repositório único).

---

## 🗺️ Mapa da Estrutura do Repositório

```text
argo/
├── k3d-config.yaml                    <-- Configuração declarativa do cluster k3d 'argo-lab'
├── setup.ps1                          <-- Script de bootstrap completo do ambiente
│
├── argocd/                            <-- Configurações do próprio Argo CD e Bootstrap
│   ├── configmap-argo-interno.yaml    <-- Modo HTTP (server.insecure) para evitar loop TLS com o Traefik
│   ├── ingress.yaml                   <-- Expõe a UI do Argo CD em http://argocd.localhost:8080
│   └── root-app.yaml                  <-- O "App of Apps" (você dá kubectl apply nele 1 única vez)
│
├── apps/                              <-- O root-app vigia ESTA pasta automaticamente
│   └── guestbook-app.yaml             <-- kind: Application (aponta para manifests/guestbook)
│
└── manifests/                         <-- Os YAMLs reais de Kubernetes de cada app moram aqui!
    └── guestbook/
        ├── guestbook-ui-deployment.yaml
        ├── guestbook-ui-ingress.yaml  <-- Expõe a app em http://guestbook.localhost:8080
        └── guestbook-ui-svc.yaml
```

---

## 🧠 Como Funciona a Arquitetura (Os 2 Níveis de YAML)

Para não confundir o que cada arquivo faz, separe o repositório em **dois níveis**:

1. **Nível 1 — Os Manifestos Kubernetes (`manifests/<nome-do-app>/`):**
   - Contém os objetos nativos do Kubernetes (`Deployment`, `Service`, `Ingress`, `ConfigMap`, etc.).
   - É aqui que ficam a **imagem do container** (`image:`), número de **réplicas** (`replicas:`), portas e variáveis de ambiente.
2. **Nível 2 — As "Fichas de Cadastro" no Argo CD (`apps/<nome-do-app>.yaml`):**
   - Contém apenas objetos `kind: Application` do Argo CD.
   - Funciona como um **ponteiro** dizendo ao Argo CD: *"Vigie a pasta `manifests/<app>` deste repositório e aplique no namespace `<ns>`"*.
3. **O Maestro — O "App of Apps" (`argocd/root-app.yaml`):**
   - É uma `Application` especial cuja única missão é vigiar a pasta `apps/`.
   - Graças a ele, você **nunca mais precisa rodar `kubectl apply`** ao criar ou alterar aplicações.

> [!IMPORTANT]
> **Regra de Ouro:** Nunca misture `Deployment`/`Service` diretamente dentro da pasta `apps/`. Na pasta `apps/` entram apenas arquivos `kind: Application`, enquanto os manifestos reais das aplicações ficam organizados em subpastas dentro de `manifests/`.

### Comparativo: Sem App of Apps vs. Com App of Apps

| O que você quer fazer | Sem App of Apps | Com App of Apps (`root-app.yaml`) |
| :--- | :--- | :--- |
| **Mudar a `image:` ou `replicas:` de um app** | **Automático via Git** (commita em `manifests/` e dá Sync) | **Automático via Git** (commita em `manifests/` e o Argo atualiza) |
| **Mudar qual pasta/branch/namespace o app usa** | **Manual** (precisa rodar `kubectl apply` ou editar na UI) | **Automático via Git** (edita e commita na pasta `apps/`) |
| **Criar um 2º, 3º, 10º app novo no cluster** | **Manual** (`kubectl apply` para cada novo app) | **Automático via Git** (basta criar o `.yaml` na pasta `apps/`) |
| **Remover um app inteiro do cluster** | **Manual** (`kubectl delete application ...`) | **Automático via Git** (basta deletar o `.yaml` da pasta `apps/`) |

---

## 🚀 Como Subir o Ambiente do Zero

### Opção A: Automática (via Script PowerShell)
O script [`setup.ps1`](./setup.ps1) faz o bootstrap completo de ponta a ponta (cria o cluster k3d, instala o Argo CD, configura o Ingress HTTP, aplica o `root-app` e já exibe a senha do `admin` no terminal):
```powershell
.\setup.ps1
```

### Opção B: Passo a Passo Manual

#### 1. Criar o Cluster k3d
```powershell
k3d cluster create --config k3d-config.yaml
```

#### 2. Instalar e Configurar o Argo CD
```powershell
kubectl create namespace argocd
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aplicar configuração HTTP + Ingress para acesso direto sem port-forward
kubectl apply -f argocd/configmap-argo-interno.yaml
kubectl rollout restart deployment argocd-server -n argocd
kubectl apply -f argocd/ingress.yaml
```

#### 3. Acessar a Interface Web (UI)
- **URL:** [http://argocd.localhost:8080](http://argocd.localhost:8080)
- **Usuário:** `admin`
- **Obter a senha inicial (PowerShell):**
  ```powershell
  $password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
  ```
- ⚠️ **Dica:** Desative o **Tradutor Automático** do navegador em `http://argocd.localhost:8080` para evitar que ele traduza valores internos nos formulários YAML (ex.: traduzir `project: default` para `project: padrao`).

#### 4. Ativar o Autogerenciamento (App of Apps) — *Único `kubectl apply` necessário!*
Depois de fazer `git commit` e `git push` das suas alterações para o GitHub, aplique o `root-app`:
```powershell
kubectl apply -f argocd/root-app.yaml
```
A partir desse momento:
1. O `root-app` aparece na UI do Argo CD.
2. Ele lê a pasta `apps/` no GitHub, encontra o `guestbook-app.yaml` e cria automaticamente a aplicação `guestbook`.
3. A aplicação `guestbook` lê a pasta `manifests/guestbook/` e sobe o `Deployment` e o `Service` no namespace `guestbook`.

---

## 🌐 Como Acessar as Aplicações (Ex: `guestbook`)

Por padrão, o `Service` da aplicação `guestbook` ([`manifests/guestbook/guestbook-ui-svc.yaml`](./manifests/guestbook/guestbook-ui-svc.yaml)) é do tipo **`ClusterIP`** (acessível apenas de dentro do cluster). Você tem **duas formas** de acessá-la pelo navegador da sua máquina:

### Opção 1: Acesso Rápido via `port-forward` (Sem alterar código)
Ideal para um teste rápido local. Abra um terminal e rode:
```powershell
kubectl port-forward svc/guestbook-ui -n guestbook 8081:80
```
- **URL:** [http://localhost:8081](http://localhost:8081) *(enquanto o comando estiver rodando no terminal)*

### Opção 2: Acesso Permanente via Traefik Ingress (Padrão GitOps ⭐)
Como o cluster k3d já mapeia a porta `8080` do Windows para a porta `80` do LoadBalancer (Traefik), basta criar um arquivo **`manifests/guestbook/guestbook-ui-ingress.yaml`** exatamente como fizemos para o Argo CD:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: guestbook-ui-ingress
  namespace: guestbook
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: traefik
  rules:
    - host: guestbook.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: guestbook-ui
                port:
                  number: 80
```
Depois de salvar o arquivo, basta seguir o fluxo GitOps (`git add .`, `git commit`, `git push`). Assim que o Argo CD sincronizar, sua aplicação estará disponível permanentemente (sem precisar de `port-forward`) em:
- **URL:** [http://guestbook.localhost:8080](http://guestbook.localhost:8080)

---

## 🔄 Fluxo de Trabalho no Dia a Dia (GitOps)

### Como atualizar uma aplicação existente (ex.: mudar réplicas ou imagem)
1. Edite [`manifests/guestbook/guestbook-ui-deployment.yaml`](./manifests/guestbook/guestbook-ui-deployment.yaml) (ex.: altere `replicas: 1` para `replicas: 3`).
2. Faça commit e push:
   ```powershell
   git add .
   git commit -m "feat(guestbook): escala para 3 replicas"
   git push
   ```
3. Clique em **Refresh** na aplicação `guestbook` na UI do Argo CD (ou aguarde o ciclo automático de 3 minutos).

### Como adicionar uma nova aplicação no cluster
1. Crie uma pasta `manifests/minha-nova-app/` e coloque lá os YAMLs (`deployment.yaml`, `service.yaml`, etc.).
2. Crie um arquivo `apps/minha-nova-app.yaml` copiando a estrutura do [`apps/guestbook-app.yaml`](./apps/guestbook-app.yaml) e apontando `spec.source.path` para `manifests/minha-nova-app`.
3. Faça `git add .`, `git commit` e `git push`.
4. Dê **Refresh** no `root-app` na UI do Argo CD — a nova aplicação nascerá sozinha!

---

## 🛠️ Comandos Úteis do Dia a Dia

```powershell
# Listar todas as Applications cadastradas no Argo CD
kubectl get applications -n argocd

# Pausar o cluster (economizar RAM/CPU sem perder dados)
k3d cluster stop argo-lab

# Iniciar o cluster novamente
k3d cluster start argo-lab

# Destruir o cluster completamente
k3d cluster delete argo-lab
```
