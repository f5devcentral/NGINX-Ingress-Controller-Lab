# NGINX Plus Ingress Controller installation

* NGINX Ingress Controller documentation: https://docs.nginx.com//nginx-ingress-controller/
* Installation with manifests: https://docs.nginx.com/nginx-ingress-controller/installation/installing-nic/installation-with-manifests/

### Clone the NGINX Ingress Controller repository
```code
git clone https://github.com/nginxinc/kubernetes-ingress.git --branch v3.6.1
```

```code
cd kubernetes-ingress
```

### Setup RBAC
```code
kubectl apply -f deployments/common/ns-and-sa.yaml
```
```code
kubectl apply -f deployments/rbac/rbac.yaml
```
```code
kubectl apply -f deployments/rbac/ap-rbac.yaml
```

### Create common resources

<!--- kubectl apply -f examples/shared-examples/default-server-secret/default-server-secret.yaml ---> 

#### Create a ConfigMap for the global NGINX configuration

```code
kubectl apply -f deployments/common/nginx-config.yaml
```

#### Create an ingressclass resource
```code
kubectl apply -f deployments/common/ingress-class.yaml
```

#### Deploy NGINX Plus Ingress Controller CRDs
```code
kubectl apply -f deploy/crds.yaml
```

#### Deploy NGINX App Protect WAF CRDs
```code
kubectl apply -f ./deploy/crds-nap-waf.yaml
```

### Deploy NGINX Ingress Controller

#### Create the authentication Kubernetes secret

This secret is needed to be able to pull the NGINX Plus Ingress Controller docker image from the NGINX private registry
```code
kubectl create secret docker-registry regcred --docker-server=private-registry.nginx.com --docker-username=<JWT Token> --docker-password=none -n nginx-ingress 
```

#### Apply NGINX Ingress Controller manifests

Apply the Deployment manifest to install NGINX Ingress Controller
```code
kubectl apply -f ../NGINX-Ingress-Controller-Lab/setup/manifests/nginx-plus-ingress.yaml
```

Expose NGINX Ingress Controller through AWS Load Balancer
```code
kubectl apply -f ../NGINX-Ingress-Controller-Lab/setup/manifests/nginx-plus-ingress-svc.yaml
```

### Test NGINX Ingress Controller reachability

Get the Internet-facing, external hostname for the NGINX Ingress Controller
```code
WSParticipantRole:~/environment/kubernetes-ingress ((v3.6.1)) $ kubectl get svc -n nginx-ingress
NAME            TYPE           CLUSTER-IP      EXTERNAL-IP                                                               PORT(S)                      AGE
nginx-ingress   LoadBalancer   172.20.180.63   <NGINX_IC_HOSTNAME>.us-west-2.elb.amazonaws.com   80:32242/TCP,443:31449/TCP   3m53s
```

Send an HTTP request to verify NGINX Ingress Controller can be reached
```code
curl -i http://<NGINX_IC_HOSTNAME>.us-west-2.elb.amazonaws.com
```

The expected response is:
```
HTTP/1.1 404 Not Found
Server: nginx/1.25.5
Date: Wed, 14 Aug 2024 14:41:24 GMT
Content-Type: text/html
Content-Length: 153
Connection: keep-alive

<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx/1.25.5</center>
</body>
</html>
```
