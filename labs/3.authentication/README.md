# JWT Token authentication

This use case shows how to enforce JWT authentication at the NGINX Ingress Controller level

Save the public FQDN for NGINX Ingress Controller
```code
export FQDN=`kubectl get svc -n nginx-ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'`
```

Check the public FQDN
```code
echo $FQDN
```

`cd` into the lab directory
```code
cd ~/environment/NGINX-Ingress-Controller-Lab/labs/3.authentication
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

Describe the `webapp` virtualserver
```code
kubectl describe vs webapp
```

Output should be similar to
```
Name:         webapp
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  k8s.nginx.org/v1
Kind:         VirtualServer
Metadata:
  Creation Timestamp:  2024-08-15T13:11:27Z
  Generation:          1
  Resource Version:    31556
  UID:                 e2af5849-3079-4069-8a04-67957f843e25
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
  External Endpoints:
    Hostname:  ac06cff94afb14336bf40e5b194d8da0-1998712692.us-west-2.elb.amazonaws.com
    Ports:     [80,443]
  Message:     Configuration for default/webapp was added or updated 
  Reason:      AddedOrUpdated
  State:       Valid
Events:
  Type    Reason          Age   From                      Message
  ----    ------          ----  ----                      -------
  Normal  AddedOrUpdated  114s  nginx-ingress-controller  Configuration for default/webapp was added or updated
```

# Test application access

Access the application without a JWT token

```code
curl -i -H "Host: webapp.example.com" http://$FQDN
```

The reply should be similar to
```
HTTP/1.1 401 Unauthorized
Server: nginx/1.25.5
Date: Thu, 15 Aug 2024 13:14:58 GMT
Content-Type: text/html
Content-Length: 179
Connection: keep-alive
WWW-Authenticate: Bearer realm="MyProductAPI"

<html>
<head><title>401 Authorization Required</title></head>
<body>
<center><h1>401 Authorization Required</h1></center>
<hr><center>nginx/1.25.5</center>
</body>
</html>
```

Access the application using a valid JWT token

```code
curl -i -H "Host: webapp.example.com" http://$FQDN -H "token: `cat token.jwt`"
```

The reply should be similar to
```
HTTP/1.1 200 OK
Server: nginx/1.25.5
Date: Thu, 15 Aug 2024 13:16:17 GMT
Content-Type: text/plain
Content-Length: 155
Connection: keep-alive
Expires: Thu, 15 Aug 2024 13:16:16 GMT
Cache-Control: no-cache

Server address: 10.42.127.0:8080
Server name: webapp-6db59b8dcc-hrtjf
Date: 15/Aug/2024:13:16:17 +0000
URI: /
Request ID: 2123f3d5709346f0db0e35fc0051e0e6HTTP/1.1 200 OK
```

Delete the lab

```code
kubectl delete -f .
```
