# NGINX Plus Ingress Controller installation

* NGINX Ingress Controller documentation: https://docs.nginx.com//nginx-ingress-controller/
* Installation with manifests: https://docs.nginx.com/nginx-ingress-controller/installation/installing-nic/installation-with-manifests/

### Setup RBAC
```code
kubectl apply -f deployments/common/ns-and-sa.yaml
```
```code
kubectl apply -f deployments/common/rbac.yaml
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
Create and environment variable called JWT_TOKEN with the token value provided by the instructor.  
```code
JWT_TOKEN=<insert JWT TOKEN>
````
Create a Kubernetes secret to hold the JWT Token. This token is needed to be able to download the NGINX+ version of Ingress Controller.  
```code
./create_secret.sh
```
```code
kubectl apply -f deployments/deployment/nginx-plus-ingress.yaml
```

