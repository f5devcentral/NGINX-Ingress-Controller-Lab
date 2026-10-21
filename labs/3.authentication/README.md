# JWT Token authentication

This use case shows how to enforce JWT authentication at the NGINX Ingress Controller level

## Architecture and Traffic Flow

The following diagram illustrates the architecture and traffic flow for this lab:

![Traffic Flow](03-authentication.svg)

Get NGINX Ingress Controller Node IP, HTTP and HTTPS NodePorts
```code
export NIC_IP=`kubectl get pod -l app.kubernetes.io/instance=nic -n nginx-ingress -o json|jq '.items[0].status.hostIP' -r`
export HTTP_PORT=`kubectl get svc nic-nginx-ingress-controller -n nginx-ingress -o jsonpath='{.spec.ports[0].nodePort}'`
export HTTPS_PORT=`kubectl get svc nic-nginx-ingress-controller -n nginx-ingress -o jsonpath='{.spec.ports[1].nodePort}'`
```

Check NGINX Ingress Controller IP address, HTTP and HTTPS ports
```code
echo -e "NIC address: $NIC_IP\nHTTP port  : $HTTP_PORT\nHTTPS port : $HTTPS_PORT"
```

`cd` into the lab directory
```code
cd ~/NGINX-Ingress-Controller-Lab/labs/3.authentication
```

Deploy the sample web applications
```code
kubectl apply -f 0.webapp.yaml
```

Deploy the JWK secret
```code
kubectl apply -f 1.jwk-secret.yaml
```

Deploy the JWT policy
```code
kubectl apply -f 2.jwt-policy.yaml
```

Publish the application through NGINX Ingress Controller applying the JWT policy
```code
kubectl apply -f 3.virtual-server.yaml
```

Check the newly created `VirtualServer` resource
```code
kubectl get vs -o wide
```

Output should be similar to
```code
NAME     STATE   HOST                 IP    EXTERNALHOSTNAME   PORTS   AGE
webapp   Valid   webapp.example.com                                    33s
```

Describe the `webapp` virtualserver
```code
kubectl describe vs webapp
```

Output should be similar to
```code
Name:         webapp
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  k8s.nginx.org/v1
Kind:         VirtualServer
Metadata:
  Creation Timestamp:  2025-04-03T18:01:01Z
  Generation:          1
  Resource Version:    227335
  UID:                 af70fa4f-2dbc-4412-a311-88b861deb52d
Spec:
  Host:  webapp.example.com
  Policies:
    Name:  jwt-policy
  Routes:
    Action:
      Pass:  webapp
    Path:    /
  Upstreams:
    Name:     webapp
    Port:     80
    Service:  webapp-svc
Status:
  Message:  Configuration for default/webapp was added or updated 
  Reason:   AddedOrUpdated
  State:    Valid
Events:
  Type    Reason          Age   From                      Message
  ----    ------          ----  ----                      -------
  Normal  AddedOrUpdated  11s   nginx-ingress-controller  Configuration for default/webapp was added or updated
```

# Test application access

Access the application without a JWT token

```code
curl -i -H "Host: webapp.example.com" http://$NIC_IP:$HTTP_PORT
```

The reply should be similar to
```
HTTP/1.1 401 Unauthorized
Server: nginx/1.27.2
Date: Thu, 03 Apr 2025 18:02:15 GMT
Content-Type: text/html
Content-Length: 179
Connection: keep-alive
WWW-Authenticate: Bearer realm="MyProductAPI"

<html>
<head><title>401 Authorization Required</title></head>
<body>
<center><h1>401 Authorization Required</h1></center>
<hr><center>nginx/1.27.2</center>
</body>
</html>
```

Access the application using a valid JWT token

```code
curl -i -H "Host: webapp.example.com" http://$NIC_IP:$HTTP_PORT -H "token: `cat token.jwt`"
```

The reply should be similar to
```code
HTTP/1.1 200 OK
Server: nginx/1.27.2
Date: Thu, 03 Apr 2025 18:03:47 GMT
Content-Type: text/plain
Content-Length: 158
Connection: keep-alive
Expires: Thu, 03 Apr 2025 18:03:46 GMT
Cache-Control: no-cache

Server address: 192.168.36.101:8080
Server name: webapp-6db59b8dcc-ltt6p
Date: 03/Apr/2025:18:03:47 +0000
URI: /
Request ID: 647bb23b4b46630207ec55267584d403
```

Delete the lab

```code
kubectl delete -f .
```
