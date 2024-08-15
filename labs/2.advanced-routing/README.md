# Advanced Layer 7 routing

This use case shows how to perform advanced layer 7 routing based on HTTP Cookies and HTTP method for an application with
four services: `tea-post-svc`, `tea-svc`, `coffee-v1-svc` and `coffee-v2-svc`

- POST requests for `/tea` are routed `tea-post-svc`
- non-POST requests for `tea` are routed to `tea-svc`
- Requests for `/coffee` that include the cookie `version` set to `v2` are routed to `coffee-v2-svc`
- Requests for `/coffee` with no `version` coookie are routed to `coffee-v1-svc`

Save the public FQDN for NGINX Ingress Controller
```code
export FQDN=`kubectl get svc -n nginx-ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'`
```

Check the public FQDN
```code
echo $FQDN
```

Deploy two sample web applications
```code
kubectl apply -f 0.cafe.yaml
```

Create TLS certificate and key to be used for TLS offload
```code
kubectl apply -f 1.cafe-secret.yaml
```

Publish `coffee` and `tea` through NGINX Ingress Controller using the `VirtualServer` Custom Resource Definition
```code
kubectl apply -f 2.advanced-routing.yaml
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

# Test application access

Access the `tea` service using a `GET` request
```code
curl --insecure --connect-to cafe.example.com:443:$FQDN https://cafe.example.com/tea
```

The `tea` service replies
```
Server address: 10.42.191.225:8080
Server name: tea-596697966f-mhd9k
Date: 15/Aug/2024:11:48:08 +0000
URI: /tea
Request ID: 1d165e7163511916e7b0f30f8c5ac7ec
```

Access the `tea-post` service using a `POST` request
```code
curl --insecure --connect-to cafe.example.com:443:$FQDN https://cafe.example.com/tea -X POST
```

The `tea-post` service replies
```e
Server address: 10.42.191.227:8080
Server name: tea-post-5647b8d885-9ssht
Date: 15/Aug/2024:11:49:13 +0000
URI: /tea
Request ID: b30d5ca917566ec79d232aee71585346
```

Access the `coffee` service sending a request with the cookie `version=v2`
```code
curl --insecure --connect-to cafe.example.com:443:$FQDN https://cafe.example.com/coffee --cookie "version=v2"
```

The `coffee-v2` service replies
```
Server address: 10.42.191.226:8080
Server name: coffee-v2-685fd9bb65-q5wtb
Date: 15/Aug/2024:12:51:06 +0000
URI: /coffee
Request ID: c42ecb435ae65e26caa0c5b6a2b8bb23
```

Access the `coffee` service sending a request without the cookie
```code
curl --insecure --connect-to cafe.example.com:443:$FQDN https://cafe.example.com/coffee
```

The `coffee-v1` service replies
```
Server address: 10.42.158.35:8080
Server name: coffee-v1-c48b96b65-vhvbm
Date: 15/Aug/2024:12:52:08 +0000
URI: /coffee
Request ID: 346f210ff4e6276f9347d02c2c8c6387
```

Delete the lab

```code
kubectl delete -f .
```
