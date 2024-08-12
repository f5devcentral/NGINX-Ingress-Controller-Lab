# NGINX+ Ingress Controller installation

<!--- setup rbac ---> 
kubectl apply -f deployments/common/ns-and-sa.yaml<br>
kubectl apply -f deployments/common/ns-and-sa.yaml<br>
kubectl apply -f deployments/rbac/ap-rbac.yaml<br>

<!--- create common resources ---> 

<!--- create default server secret ---> 
<!--- kubectl apply -f examples/shared-examples/default-server-secret/default-server-secret.yaml ---> 

<!--- create a configmap ---> 
kubectl apply -f deployments/common/nginx-config.yaml

<!--- create an ingress-class ---> 
kubectl apply -f deployments/common/ingress-class.yaml

<!--- create crds ---> 
kubectl apply -f config/crd/bases/externaldns.nginx.org_dnsendpoints.yaml
kubectl apply -f config/crd/bases/k8s.nginx.org_globalconfigurations.yaml
kubectl apply -f config/crd/bases/k8s.nginx.org_policies.yaml
kubectl apply -f config/crd/bases/k8s.nginx.org_transportservers.yaml
kubectl apply -f config/crd/bases/k8s.nginx.org_virtualserverroutes.yaml
kubectl apply -f config/crd/bases/k8s.nginx.org_virtualservers.yaml
kubectl apply -f config/crd//bases/appprotect.f5.com_aplogconfs.yaml
kubectl apply -f config/crd//bases/appprotect.f5.com_appolicies.yaml
kubectl apply -f config/crd//bases/appprotect.f5.com_apusersigs.yaml

<!--- deploy N+ ---> 
kubectl apply -f deployments/deployment/nginx-plus-ingress.yaml

