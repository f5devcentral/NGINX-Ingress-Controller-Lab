# NGINX+ Ingress Controller installation

<!--- setup rbac ---> 
`kubectl apply -f deployments/common/ns-and-sa.yaml`<br>
`kubectl apply -f deployments/common/ns-and-sa.yaml`<br>
`kubectl apply -f deployments/rbac/ap-rbac.yaml`<br>

<!--- create common resources ---> 

<!--- create default server secret ---> 
<!--- kubectl apply -f examples/shared-examples/default-server-secret/default-server-secret.yaml ---> 

<!--- create a configmap ---> 
`kubectl apply -f deployments/common/nginx-config.yaml`

<!--- create an ingress-class ---> 
`kubectl apply -f deployments/common/ingress-class.yaml`

<!--- create crds ---> 
`kubectl apply -f config/crd/bases/externaldns.nginx.org_dnsendpoints.yaml`<br>
`kubectl apply -f config/crd/bases/k8s.nginx.org_globalconfigurations.yaml`<br>
`kubectl apply -f config/crd/bases/k8s.nginx.org_policies.yaml`<br>
`kubectl apply -f config/crd/bases/k8s.nginx.org_transportservers.yaml`<br>
`kubectl apply -f config/crd/bases/k8s.nginx.org_virtualserverroutes.yaml`<br>
`kubectl apply -f config/crd/bases/k8s.nginx.org_virtualservers.yaml`<br>
`kubectl apply -f config/crd//bases/appprotect.f5.com_aplogconfs.yaml`<br>
`kubectl apply -f config/crd//bases/appprotect.f5.com_appolicies.yaml`<br>
`kubectl apply -f config/crd//bases/appprotect.f5.com_apusersigs.yaml`<br>`

<!--- deploy N+ ---> 
`kubectl apply -f deployments/deployment/nginx-plus-ingress.yaml`<br>

