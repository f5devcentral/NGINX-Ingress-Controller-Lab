# NGINX Plus Ingress Controller installation

NGINX Ingress Controller documentation: https://docs.nginx.com//nginx-ingress-controller/

Installation with manifests: https://docs.nginx.com/nginx-ingress-controller/installation/installing-nic/installation-with-manifests/

### Setup RBAC
```code
kubectl apply -f deployments/common/ns-and-sa.yaml
```
```code
kubectl apply -f deployments/common/ns-and-sa.yaml
```
```code
kubectl apply -f deployments/rbac/ap-rbac.yaml
```

<!--- create common resources ---> 
### create common resources
<!--- create default server secret ---> 
<!--- kubectl apply -f examples/shared-examples/default-server-secret/default-server-secret.yaml ---> 

#### Create a ConfigMap

```code
kubectl apply -f deployments/common/nginx-config.yaml
```

#### Create an ingress-class
```code
kubectl apply -f deployments/common/ingress-class.yaml
```

#### Deploy CRD's
```code
kubectl apply -f config/crd/bases/externaldns.nginx.org_dnsendpoints.yaml
```
```code
kubectl apply -f config/crd/bases/k8s.nginx.org_globalconfigurations.yaml
```
```code
kubectl apply -f config/crd/bases/k8s.nginx.org_policies.yaml
```
```code
kubectl apply -f config/crd/bases/k8s.nginx.org_transportservers.yaml
```
```code
kubectl apply -f config/crd/bases/k8s.nginx.org_virtualserverroutes.yaml
```
```code
kubectl apply -f config/crd/bases/k8s.nginx.org_virtualservers.yaml
```
```code
kubectl apply -f config/crd//bases/appprotect.f5.com_aplogconfs.yaml
```
```code
kubectl apply -f config/crd//bases/appprotect.f5.com_appolicies.yaml
```
```code
kubectl apply -f config/crd//bases/appprotect.f5.com_apusersigs.yaml
```

### Deploy N+
```code
kubectl apply -f deployments/deployment/nginx-plus-ingress.yaml
```

