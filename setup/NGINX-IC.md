# NGINX Plus Ingress Controller installation

Lab time: ~20 minutes

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

Note: The JWT authentication token will be provided by the instructor

This secret is needed to be able to pull the NGINX Plus Ingress Controller docker image from the NGINX private registry
```code
kubectl create secret docker-registry regcred --docker-server=private-registry.nginx.com --docker-username=<JWT Token> --docker-password=none -n nginx-ingress 
```

#### Apply NGINX Ingress Controller manifests

Apply the Deployment manifest to install NGINX Ingress Controller
```code
kubectl apply -f ../NGINX-Ingress-Controller-Lab/setup/manifests/nginx-plus-ingress.yaml
```

Publish NGINX Ingress Controller through AWS Load Balancer
```code
kubectl apply -f ../NGINX-Ingress-Controller-Lab/setup/manifests/nginx-plus-ingress-svc.yaml
```

### Check NGINX Ingress Controller status

Verify that the NGINX Ingress Controller pod is in the `Running` state
```code
kubectl get pods -n nginx-ingress
```

Output should be similar to
```
NAME                             READY   STATUS    RESTARTS   AGE
nginx-ingress-5c6c847f86-c4vmw   1/1     Running   0          4s
```

Check the Internet-facing, external FQDN for the NGINX Ingress Controller
```code
kubectl get svc -n nginx-ingress
```

Output should be similar to
```
NAME            TYPE           CLUSTER-IP      EXTERNAL-IP                             PORT(S)                      AGE
nginx-ingress   LoadBalancer   172.20.180.63   <NGINX_IC_HOSTNAME>.elb.amazonaws.com   80:32242/TCP,443:31449/TCP   3m53s
```

Save the external FQDN to an environment variable
```code
export FQDN=`kubectl get svc -n nginx-ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'`
```

Check the public FQDN
```code
echo $FQDN
```

Send an HTTP request to verify NGINX Ingress Controller can be reached. It might a few seconds for NGINX to be reachable from the public Internet after the initial deployment
```code
curl -i http://$FQDN
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

Check NGINX Ingress Controller pod logs
```code
kubectl logs -l app=nginx-ingress -n nginx-ingress
```

Output should be similar to
```
New level: TS_CRIT
New file num: 2
New ALL module: ALL
New ALL level: TS_ERR
New ALL level: TS_WARNING
New ALL level: TS_NOTICE
New ALL level: TS_CRIT
New ALL file num: 2
I0815 09:34:56.602065       1 leaderelection.go:260] successfully acquired lease nginx-ingress/nginx-ingress-leader-election
10.42.88.234 - - [15/Aug/2024:09:39:56 +0000] "GET / HTTP/1.1" 404 153 "-" "curl/8.3.0" "-"
```
