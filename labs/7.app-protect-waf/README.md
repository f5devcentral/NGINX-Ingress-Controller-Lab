# NGINX App Protect WAF

This use case applies WAF protection to a sample application exposed through NGINX Ingress Controller

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

Deploy the syslog service to receive NGINX App Protect security violations logs
```code
kubectl apply -f 1.syslog.yaml
```

Deploy the NGINX App Protect policy resources
```code
kubectl apply -f 2.ap-apple-uds.yaml
```

```code
kubectl apply -f 3.ap-dataguard-alarm-policy.yaml
```

```code
kubectl apply -f 4.ap-logconf.yaml
```

Deploy the WAF policy
```code
kubectl apply -f 5.waf.yaml
```

Publish the application through NGINX Ingress Controller applying the WAF policy
```code
kubectl apply -f 6.virtual-server.yaml
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
  Creation Timestamp:  2024-08-15T15:24:00Z
  Generation:          1
  Resource Version:    59184
  UID:                 cd81a06e-48d5-46aa-b44c-0a17e35e8664
Spec:
  Host:  webapp.example.com
  Policies:
    Name:  waf-policy
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
  Normal  AddedOrUpdated  13s   nginx-ingress-controller  Configuration for default/webapp was added or updated
```

Access the application using a legitimate request
```code
curl -i -H "Host: webapp.example.com" http://$FQDN
```

Output should be similar to
```
HTTP/1.1 200 OK
Date: Thu, 15 Aug 2024 15:26:56 GMT
Content-Type: text/plain
Content-Length: 157
Connection: keep-alive
Expires: Thu, 15 Aug 2024 15:26:55 GMT
Cache-Control: no-cache

Server address: 10.42.124.176:8080
Server name: webapp-6db59b8dcc-vwn6p
Date: 15/Aug/2024:15:26:56 +0000
URI: /
Request ID: a9c2971d52f3bd7a4a642bbde1868edd
```

Access the application using a suspicious URL
```
curl -i -H "Host: webapp.example.com" "http://$FQDN/<script>"
```

Output should be similar to
```
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Connection: close
Cache-Control: no-cache
Pragma: no-cache
Content-Length: 246

<html><head><title>Request Rejected</title></head><body>The requested URL was rejected. Please consult with your administrator.<br><br>Your support ID is: 4791600865828351744<br><br><a href='javascript:history.back();'>[Go Back]</a></body></html>
```

Access the application sending data that matches the user defined signature
```
curl -i -H "Host: webapp.example.com" http://$FQDN -X POST -d "apple"
```

Output should be similar to
```
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Connection: close
Cache-Control: no-cache
Pragma: no-cache
Content-Length: 246

<html><head><title>Request Rejected</title></head><body>The requested URL was rejected. Please consult with your administrator.<br><br>Your support ID is: 8869365625080570970<br><br><a href='javascript:history.back();'>[Go Back]</a></body></html>
```

Check the security violation logs in the `syslog` pod
```
export SYSLOG_POD_NAME=`kubectl get pods -l app=syslog -o jsonpath='{.items[0].metadata.name}'`
kubectl exec -it $SYSLOG_POD_NAME -- cat /var/log/messages
```

Delete the lab

```code
kubectl delete -f .
```
