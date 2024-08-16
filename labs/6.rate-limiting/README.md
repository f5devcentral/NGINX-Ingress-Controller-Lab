# Rate Limiting

This use case applies rate limiting for an application exposed through NGINX Ingress Controller

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
cd ~/environment/NGINX-Ingress-Controller-Lab/labs/6.rate-limiting
```

Deploy the sample web applications
```code
kubectl apply -f 0.webapp.yaml
```

Deploy a rate limit policy that allows only 1 request per second from a single IP address
```code
kubectl apply -f 1.rate-limit.yaml
```

Publish the application through NGINX Ingress Controller applying the rate limit policy
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
  Creation Timestamp:  2024-08-15T14:44:57Z
  Generation:          1
  Resource Version:    50998
  UID:                 88ea7685-3f25-405a-9929-a36d8c292e3a
Spec:
  Host:  webapp.example.com
  Policies:
    Name:  rate-limit-policy
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
  Type    Reason          Age    From                      Message
  ----    ------          ----   ----                      -------
  Normal  AddedOrUpdated  5m39s  nginx-ingress-controller  Configuration for default/webapp was added or updated
```

Access the application
```code
curl -i -H "Host: webapp.example.com" http://$FQDN
```

Output should be similar to
```
HTTP/1.1 200 OK
Server: nginx/1.25.5
Date: Thu, 15 Aug 2024 14:50:47 GMT
Content-Type: text/plain
Content-Length: 157
Connection: keep-alive
Expires: Thu, 15 Aug 2024 14:50:46 GMT
Cache-Control: no-cache

Server address: 10.42.124.176:8080
Server name: webapp-6db59b8dcc-zx4bm
Date: 15/Aug/2024:14:50:47 +0000
URI: /
Request ID: 0b0a532bfffd15036cdd29eb8f2eeff9
```

Access the application twice in rapid sequence
```code
curl -i -H "Host: webapp.example.com" http://$FQDN ; curl -i -H "Host: webapp.example.com" http://$FQDN
```

The first request is server and the second is rate limited with HTTP code 429
Output should be similar to
```
HTTP/1.1 200 OK
Server: nginx/1.25.5
Date: Thu, 15 Aug 2024 14:53:12 GMT
Content-Type: text/plain
Content-Length: 157
Connection: keep-alive
Expires: Thu, 15 Aug 2024 14:53:11 GMT
Cache-Control: no-cache

Server address: 10.42.124.176:8080
Server name: webapp-6db59b8dcc-zx4bm
Date: 15/Aug/2024:14:53:12 +0000
URI: /
Request ID: 4d973257f1be29181f68cba3794fa34b
HTTP/1.1 429 Too Many Requests
Server: nginx/1.25.5
Date: Thu, 15 Aug 2024 14:53:12 GMT
Content-Type: text/html
Content-Length: 169
Connection: keep-alive

<html>
<head><title>429 Too Many Requests</title></head>
<body>
<center><h1>429 Too Many Requests</h1></center>
<hr><center>nginx/1.25.5</center>
</body>
</html>
```

Delete the lab

```code
kubectl delete -f .
```
