	# F5 WAF for NGINX

This use case applies WAF protection to a sample application exposed through NGINX Ingress Controller

NGINX Ingress Controller needs to be deployed with the WAF in precompiled mode, see [DEPLOYING-WAFv5.md](/DEPLOYING-WAFv5.md)

Get NGINX Ingress Controller Node IP, HTTP and HTTPS NodePorts and pod name
```code
export NIC_IP=`kubectl get pod -l app.kubernetes.io/instance=nic -n nginx-ingress -o json|jq '.items[0].status.hostIP' -r`
export HTTP_PORT=`kubectl get svc nic-nginx-ingress-controller -n nginx-ingress -o jsonpath='{.spec.ports[0].nodePort}'`
export HTTPS_PORT=`kubectl get svc nic-nginx-ingress-controller -n nginx-ingress -o jsonpath='{.spec.ports[1].nodePort}'`
export NIC_PODNAME=`kubectl get pod -l app.kubernetes.io/instance=nic -n nginx-ingress -o json|jq '.items[0].metadata.name' -r`
```

Check NGINX Ingress Controller IP address, HTTP and HTTPS ports and pod name
```code
echo -e "NIC address: $NIC_IP\nHTTP port  : $HTTP_PORT\nHTTPS port : $HTTPS_PORT\nPod name   : $NIC_PODNAME"
```

`cd` into the lab directory
```code
cd ~/NGINX-Ingress-Controller-Lab/labs/8.waf-precompiled
```

Compile the policy bundle
```code
cd artifacts
chmod 777 .
docker run --rm \
 -v $(pwd):$(pwd) \
 waf-compiler-5.13.1:custom \
 -include-source -full-export -g $(pwd)/global_settings.json -p $(pwd)/waf_policy.json -o $(pwd)/waf_policy.tgz
```

The output should be similar to
```code
{
  "completed_successfully": true,
  "compiler_engine": "express",
  "compiler_version": "11.608.2",
  "filename": "/home/f5/work/NGINX-Ingress-Controller-Lab/labs/8.waf-precompiled/artifacts/waf_policy.tgz",
  "file_size": 1887047,
  "attack_signatures_package": {
    "version": "2026.05.27",
    "revision_datetime": "2026-05-27T18:00:54Z"
  },
  "bot_signatures_package": {
    "version": "2026.05.28",
    "revision_datetime": "2026-05-28T13:37:15Z"
  },
  "threat_campaigns_package": {
    "version": "2026.06.01",
    "revision_datetime": "2026-06-01T07:09:53Z"
  }
}
```

The policy has been compiled into `waf_policy.tgz`

Compile the WAF log profile
```code
docker run \
  -v $(pwd):$(pwd) \
  waf-compiler-5.13.1:custom \
  -l $(pwd)/log_profile.json -o $(pwd)/log_profile.tgz
```

The output should be similar to
```code
{
  "completed_successfully": true,
  "file_size": 1690,
  "compiler_engine": "full",
  "compiler_version": "11.608.2",
  "filename": "/home/f5/work/NGINX-Ingress-Controller-Lab/labs/8.waf-precompiled/artifacts/log_profile.tgz"
}
```

The log profile has been compiled into `log_profile.tgz`

Copy the compiled policy bundle and log profile into the NGINX Ingress Controller pod:
```code
kubectl cp waf_policy.tgz $NIC_PODNAME:/etc/app_protect/bundles/ -c nginx-ingress -n nginx-ingress
kubectl cp log_profile.tgz $NIC_PODNAME:/etc/app_protect/bundles/ -c nginx-ingress -n nginx-ingress
```

Change directory
```code
cd ..
```

Copy the compiled policy bundle and the compiled log profile to the relevant pods


Deploy the sample web applications
```code
kubectl apply -f 0.webapp.yaml
```

Deploy the syslog service to receive NGINX App Protect security violations logs
```code
kubectl apply -f 1.syslog.yaml
```

Deploy the WAF policy
```code
kubectl apply -f 2.waf.yaml
```

Describe the WAF policy
```code
kubectl describe policy waf-policy
```

The output should be similar to
```code
Name:         waf-policy
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  k8s.nginx.org/v1
Kind:         Policy
Metadata:
  Creation Timestamp:  2026-06-03T13:07:15Z
  Generation:          1
  Resource Version:    120952526
  UID:                 eaf848d7-bb38-452a-815b-a31ef9402127
Spec:
  Waf:
    Ap Bundle:  waf_policy.tgz
    Enable:     true
    Security Logs:
      Ap Log Bundle:  log_profile.tgz
      Enable:         true
      Log Dest:       syslog:server=syslog-svc.default:514
Status:
  Message:  Policy default/waf-policy was added or updated
  Reason:   AddedOrUpdated
  State:    Valid
Events:
  Type    Reason          Age   From                      Message
  ----    ------          ----  ----                      -------
  Normal  AddedOrUpdated  4s    nginx-ingress-controller  Policy default/waf-policy was added or updated
```

Publish the application through NGINX Ingress Controller applying the WAF policy
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
webapp   Valid   webapp.example.com                                    9m49s
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
  Creation Timestamp:  2026-06-03T13:07:58Z
  Generation:          1
  Resource Version:    120952658
  UID:                 70a421a8-baeb-4e3c-aeba-43d7c602292c
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
  Message:  Configuration for default/webapp was added or updated 
  Reason:   AddedOrUpdated
  State:    Valid
Events:
  Type    Reason          Age   From                      Message
  ----    ------          ----  ----                      -------
  Normal  AddedOrUpdated  11s   nginx-ingress-controller  Configuration for default/webapp was added or updated
```

Access the application using a legitimate request
```code
curl -i -H "Host: webapp.example.com" http://$NIC_IP:$HTTP_PORT
```

Output should be similar to
```code
HTTP/1.1 200 OK
Date: Wed, 03 Jun 2026 13:12:48 GMT
Content-Type: text/plain
Content-Length: 153
Connection: keep-alive
Expires: Wed, 03 Jun 2026 13:12:47 GMT
Cache-Control: no-cache

Server address: 10.0.86.8:8080
Server name: webapp-558ff5c8f6-5jpvl
Date: 03/Jun/2026:13:12:48 +0000
URI: /
Request ID: 740e25c98fd7e928b1bbad6e11e2fc7e
```

Access the application using a suspicious URL
```code
curl -i -H "Host: webapp.example.com" "http://$NIC_IP:$HTTP_PORT/<script>alert();</script>"
```

Output should be similar to
```code
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Connection: close
Cache-Control: no-cache
Pragma: no-cache
Content-Length: 246

<html><head><title>Request Rejected</title></head><body>The requested URL was rejected. Please consult with your administrator.<br><br>Your support ID is: 5712263780975477505<br><br><a href='javascript:history.back();'>[Go Back]</a></body></html>
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
