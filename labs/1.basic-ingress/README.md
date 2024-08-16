# Basic Ingress Controller

This use case shows how to publish two sample applications using:

- URI-based routing
- TLS offload

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
cd ~/environment/NGINX-Ingress-Controller-Lab/labs/1.basic-ingress
```

Deploy two sample web applications
```code
kubectl apply -f 0.cafe.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```
NAME                          READY   STATUS    RESTARTS   AGE
pod/coffee-56b44d4c55-4v6jp   1/1     Running   0          32s
pod/coffee-56b44d4c55-gdgdw   1/1     Running   0          32s
pod/tea-596697966f-cc4zj      1/1     Running   0          28m
pod/tea-596697966f-hbt7x      1/1     Running   0          28m
pod/tea-596697966f-mhd9k      1/1     Running   0          28m

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/coffee-svc   ClusterIP   172.20.10.229   <none>        80/TCP    28m
service/kubernetes   ClusterIP   172.20.0.1      <none>        443/TCP   2d23h
service/tea-svc      ClusterIP   172.20.169.88   <none>        80/TCP    28m

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee   2/2     2            2           32s
deployment.apps/tea      3/3     3            3           28m

NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-56b44d4c55   2         2         2       32s
replicaset.apps/tea-596697966f      3         3         3       28m
```

Create TLS certificate and key to be used for TLS offload
```code
kubectl apply -f 1.cafe-secret.yaml
```

Publish `coffee` and `tea` through NGINX Ingress Controller using the `Ingress` resource
```code
kubectl apply -f 2.cafe-ingress.yaml
```

Check the newly created `Ingress` resource
```code
kubectl get ingress
```

Output should be similar to
```code
NAME           CLASS   HOSTS              ADDRESS                                                                   PORTS     AGE
cafe-ingress   nginx   cafe.example.com   a87ecf270237f42878ecc7256d2f5fa4-1110491658.us-west-2.elb.amazonaws.com   80, 443   13s
```

[Test](#test-application-access) application access

Delete the `Ingress` resource

```code
kubectl delete -f 2.cafe-ingress.yaml
```

Publish `coffee` and `tea` through NGINX Ingress Controller using the `VirtualServer` Custom Resource Definition
```code
kubectl apply -f 3.cafe-virtualserver.yaml
```

Check the newly created `VirtualServer` resource
```code
kubectl get vs -o wide
```

Output should be similar to
```code
NAME   STATE   HOST               IP    EXTERNALHOSTNAME                                                          PORTS      AGE
cafe   Valid   cafe.example.com         a87ecf270237f42878ecc7256d2f5fa4-1110491658.us-west-2.elb.amazonaws.com   [80,443]   38s
```

[Test](#test-application-access) application access

Delete the lab

```code
kubectl delete -f .
```

# Test applications access

We will use `curl` with the `--insecure` option to turn off certificate verification of our
self-signed certificate and the `--resolve` option to set the Host header and SNI of the request
with `cafe.example.com`

To access `coffee`
```code
curl --insecure --connect-to cafe.example.com:443:$FQDN https://cafe.example.com/coffee
```

Output should be similar to
```code
Server address: 10.42.158.34:8080
Server name: coffee-56b44d4c55-4v6jp
Date: 15/Aug/2024:11:08:15 +0000
URI: /coffee
Request ID: 155dbb65002cf009be77c14d5f56a4c2
```

To access `tea`
```code
curl --insecure --connect-to cafe.example.com:443:$FQDN https://cafe.example.com/tea
```

Output should be similar to
```code
Server address: 10.42.117.1:8080
Server name: tea-596697966f-cc4zj
Date: 15/Aug/2024:11:08:35 +0000
URI: /tea
Request ID: 8387ea6bd56e92e3a84d50717b8151e7
```
