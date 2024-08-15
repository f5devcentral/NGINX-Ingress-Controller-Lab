# Access Control

This use case applies access control policies to deny and allow traffic from a specific subnet

Save the public FQDN for NGINX Ingress Controller
```code
export FQDN=`kubectl get svc -n nginx-ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'`
```

Check the public FQDN
```code
echo $FQDN
```

Deploy the sample web applications
```code
kubectl apply -f 0.webapp.yaml
```

Deploy an access control policy that denies requests from clients with an IP that belongs to the subnet 10.0.0.0/8
```code
kubectl apply -f 1.access-control-policy-deny.yaml
```

Publish the application through NGINX Ingress Controller applying the access control policy
```code
kubectl apply -f 2.virtual-server.yaml
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
  Creation Timestamp:  2024-08-15T14:26:05Z
  Generation:          1
  Resource Version:    47069
  UID:                 3c2f02f0-052d-4020-bf83-a24ea1338a66
Spec:
  Host:  webapp.example.com
  Policies:
    Name:  webapp-policy
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
  Normal  AddedOrUpdated  26s   nginx-ingress-controller  Configuration for default/webapp was added or updated
```

Access the application
```code
curl -i -H "Host: webapp.example.com" http://$FQDN
```

NGINX Ingress controller blocks the request as the client IP belongs to subnet `10.0.0.0/8`
```
HTTP/1.1 403 Forbidden
Server: nginx/1.25.5
Date: Thu, 15 Aug 2024 14:27:14 GMT
Content-Type: text/html
Content-Length: 153
Connection: keep-alive

<html>
<head><title>403 Forbidden</title></head>
<body>
<center><h1>403 Forbidden</h1></center>
<hr><center>nginx/1.25.5</center>
</body>
</html>
```

Update the access control policy
```code
kubectl apply -f 3.access-control-policy-allow.yaml
```

Access the application
```code
curl -i -H "Host: webapp.example.com" http://$FQDN
```

NGINX Ingress controller allows traffic from subnet `10.0.0.0/8`
```
HTTP/1.1 200 OK
Server: nginx/1.25.5
Date: Thu, 15 Aug 2024 14:30:36 GMT
Content-Type: text/plain
Content-Length: 157
Connection: keep-alive
Expires: Thu, 15 Aug 2024 14:30:35 GMT
Cache-Control: no-cache

Server address: 10.42.124.176:8080
Server name: webapp-6db59b8dcc-g2tsd
Date: 15/Aug/2024:14:30:36 +0000
URI: /
Request ID: e08326b5f2ac13ff12cc8d02479a4098
```

Delete the lab

```code
kubectl delete -f .
```
