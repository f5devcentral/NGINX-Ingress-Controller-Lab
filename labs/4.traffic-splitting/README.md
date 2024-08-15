# Traffic Splitting

This use case configures traffic splitting for a sample application with two services: `coffee-v1-svc` and `coffee-v2-svc`
90% of the `coffee` application traffic is sent to `coffee-v1-svc` the remaining 10% to coffee-v2-svc

This use case shows how to enforce JWT authentication at the NGINX Ingress Controller level

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
kubectl apply -f 0.cafe.yaml
```

Publish the application through NGINX Ingress Controller applying the traffic splitting rule
```code
kubectl apply -f 1.virtual-server.yaml
```

Check the newly created `VirtualServer` resource
```code
kubectl get vs -o wide
```

Describe the `cafe` virtualserver
```code
kubectl describe vs cafe
```

Output should be similar to
```
Name:         cafe
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  k8s.nginx.org/v1
Kind:         VirtualServer
Metadata:
  Creation Timestamp:  2024-08-15T13:58:44Z
  Generation:          1
  Resource Version:    41375
  UID:                 699c41b0-a65a-453b-86c5-be1358467292
Spec:
  Host:  cafe.example.com
  Routes:
    Path:  /coffee
    Splits:
      Action:
        Pass:  coffee-v1
      Weight:  90
      Action:
        Pass:  coffee-v2
      Weight:  10
  Upstreams:
    Name:     coffee-v1
    Port:     80
    Service:  coffee-v1-svc
    Name:     coffee-v2
    Port:     80
    Service:  coffee-v2-svc
Status:
  External Endpoints:
    Hostname:  ac06cff94afb14336bf40e5b194d8da0-1998712692.us-west-2.elb.amazonaws.com
    Ports:     [80,443]
  Message:     Configuration for default/cafe was added or updated 
  Reason:      AddedOrUpdated
  State:       Valid
Events:
  Type    Reason          Age   From                      Message
  ----    ------          ----  ----                      -------
  Normal  AddedOrUpdated  31s   nginx-ingress-controller  Configuration for default/cafe was added or updated
```

# Test application access

Access the application
```code
curl -i -H "Host: cafe.example.com" http://$FQDN/coffee
```

90% of responses will come from `coffee-v1-svc` and be similar to
```
HTTP/1.1 200 OK
Server: nginx/1.25.5
Date: Thu, 15 Aug 2024 14:06:40 GMT
Content-Type: text/plain
Content-Length: 163
Connection: keep-alive
Expires: Thu, 15 Aug 2024 14:06:39 GMT
Cache-Control: no-cache

Server address: 10.42.151.2:8080
Server name: coffee-v1-c48b96b65-whg4d
Date: 15/Aug/2024:14:06:40 +0000
URI: /coffee
Request ID: 71b09d9c6cec888845d7a95f508d4720
```

10% of responses will come from `coffee-v2-svc` and be similar to
```
HTTP/1.1 200 OK
Server: nginx/1.25.5
Date: Thu, 15 Aug 2024 14:06:30 GMT
Content-Type: text/plain
Content-Length: 164
Connection: keep-alive
Expires: Thu, 15 Aug 2024 14:06:29 GMT
Cache-Control: no-cache

Server address: 10.42.151.1:8080
Server name: coffee-v2-685fd9bb65-6zr4k
Date: 15/Aug/2024:14:06:30 +0000
URI: /coffee
Request ID: 948bce631584e1d8e2a6d4bc611fc0a1
```

Delete the lab

```code
kubectl delete -f .
```
