$ErrorActionPreference = "Stop"

Write-Host "==> 1/4 Criando cluster k3d 'argo-lab'..." -ForegroundColor Cyan
k3d cluster create --config k3d-config.yaml

Write-Host "`n==> 2/4 Instalando o Argo CD no namespace 'argocd'..." -ForegroundColor Cyan
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.7/manifests/install.yaml

Write-Host "`n==> 3/5 Configurando Ingress e modo HTTP no argocd-server..." -ForegroundColor Cyan
kubectl apply -f argocd/configmap-argo-interno.yaml
kubectl rollout restart deployment argocd-server -n argocd
kubectl apply -f argocd/ingress.yaml

Write-Host "`n==> 4/5 Aguardando pods do Argo CD ficarem prontos..." -ForegroundColor Cyan
kubectl wait --for=condition=available deployment --all -n argocd --timeout=300s

Write-Host "`n==> 5/5 Ativando App of Apps (root-app)..." -ForegroundColor Cyan
kubectl apply -f argocd/root-app.yaml

$passwordB64 = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
$password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($passwordB64))

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " Argo CD pronto!" -ForegroundColor Green
Write-Host " URL:     http://argocd.localhost:8080"
Write-Host " Usuario: admin"
Write-Host " Senha:   $password"
Write-Host "========================================================" -ForegroundColor Green
