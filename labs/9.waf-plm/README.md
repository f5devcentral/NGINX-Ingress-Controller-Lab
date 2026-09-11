# F5 WAF for NGINX

This use case applies WAF protection to a sample application exposed through NGINX Ingress Controller using [Policy Lifecycle Manager](https://docs.nginx.com/nginx-ingress-controller/install/plm-installation/)
The NGINX Ingress Controller is deployed directly in this lab


`cd` into the lab directory
```code
cd ~/NGINX-Ingress-Controller-Lab/labs/9.waf-plm
```

## Deploy the test storage provider

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

```bash
kubectl get pods -n local-path-storage
```

Output should be similar to
```bash
NAME                                      READY   STATUS    RESTARTS   AGE
local-path-provisioner-79b7b99b5d-w69vk   1/1     Running   0          24s
```

Set the `storageclass` as default
```bash
kubectl patch storageclass local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Check the storage class
```bash
kubectl get storageclass
```

Output should be similar to
```bash
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  17m
```

## Deploy cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.21.2 \
  --namespace cert-manager \  
  --create-namespace \
  --set crds.enabled=true
```

Test cert-manager

```bash
kubectl apply -f 0.cert-manager-test.yaml
```

Check the status of the newly created certificate

```bash
kubectl describe certificate -n cert-manager-test
```

Output should be similar to

```bash
Name:         selfsigned-cert
Namespace:    cert-manager-test
Labels:       <none>
Annotations:  <none>
API Version:  cert-manager.io/v1
Kind:         Certificate
Metadata:
  Creation Timestamp:  2026-09-11T10:45:01Z
  Generation:          1
  Resource Version:    143626467
  UID:                 96ce0441-d494-49ca-a3f1-c70c7a49a78c
Spec:
  Dns Names:
    example.com
  Issuer Ref:
    Name:       test-selfsigned
  Secret Name:  selfsigned-cert-tls
Status:
  Conditions:
    Last Transition Time:  2026-09-11T10:45:01Z
    Message:               Certificate is up to date and has not expired
    Observed Generation:   1
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2026-12-10T10:45:01Z
  Not Before:              2026-09-11T10:45:01Z
  Renewal Time:            2026-11-10T10:45:01Z
  Revision:                1
Events:
  Type    Reason     Age   From                                       Message
  ----    ------     ----  ----                                       -------
  Normal  Issuing    3s    cert-manager-certificates-trigger          Issuing certificate as Secret does not exist
  Normal  Generated  3s    cert-manager-certificates-key-manager      Stored new private key in temporary Secret resource "selfsigned-cert-4jzgw"
  Normal  Requested  3s    cert-manager-certificates-request-manager  Created new CertificateRequest resource "selfsigned-cert-1"
  Normal  Issuing    3s    cert-manager-certificates-issuing          The certificate has been successfully issued
```

Remove test objects

```bash
kubectl delete -f 0.cert-manager-test.yaml
```


## Deploy Policy Lifecycle Manager

Create the `plm-system` namespace

```bash
kubectl create namespace plm-system
```

Create the authentication secrets
```bash
kubectl create secret generic jwt-reg-secret \
  --namespace plm-system \
  --from-file=<nginx-one-eval.jwt>

JWT=$(kubectl get secret jwt-reg-secret \
  --namespace plm-system \
  -o jsonpath='{.data.license\.jwt}' | base64 -d)

kubectl create secret docker-registry regcred \
  --namespace plm-system \
  --docker-server=private-registry.nginx.com \
  --docker-username="$JWT" \
  --docker-password=none \
  --dry-run=client --output yaml | kubectl apply -f -
```

Base64-encode the NGINX licence certificate and key:

```bash
cat <nginx-one-eval.crt> | base64 -w0 # Base64-encode the NGINX certificate
cat <nginx-one-eval.key> | base64 -w0 # Base64-encode the NGINX key
```

Edit `artifacts/plm-values.yaml` and paste the base64-encoded certificate and key here:

```bash
securityUpdatesRepo:
  cert: "<BASE64_ENCODED_NGINX_CERTIFICATE>"
  key: "<BASE64_ENCODED_NGINX_CERTIFICATE_KEY>"
```

Create Policy Lifecycle Manager test certificates
```bash
kubectl apply -f 1.plm-certs.yaml
```

Verify created certificates
```bash
kubectl get certificates -n plm-system
```

Output should be similar to
```bash
NAME               READY   SECRET                             AGE
seaweedfs-ca       True    plm-f5-waf-seaweedfs-ca-cert       7s
seaweedfs-client   True    plm-f5-waf-seaweedfs-client-cert   6s
seaweedfs-filer    True    plm-f5-waf-seaweedfs-filer-cert    6s
seaweedfs-master   True    plm-f5-waf-seaweedfs-master-cert   6s
seaweedfs-volume   True    plm-f5-waf-seaweedfs-volume-cert   6s
```

Deploy Policy Lifecycle Manager

```bash
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update nginx-stable

helm upgrade --install plm nginx-stable/f5-waf-policy-controller \
  --version 5.15.0 \
  --namespace plm-system \
  --values ./artifacts/plm-values.yaml
```

Verify the deployment

```bash
kubectl rollout status deployment/plm-seaweedfs-operator \
  --namespace plm-system --timeout=120s
```

Poll SeaweedFS until the pods appear and are ready

```bash
end=$((SECONDS + 300))
until kubectl wait pods \
    --selector app.kubernetes.io/name=seaweedfs \
    --for=condition=Ready \
    --namespace plm-system \
    --timeout=10s 2>/dev/null; do
  if [ $SECONDS -ge $end ]; then
    echo "Timed out waiting for SeaweedFS pods"
    exit 1
  fi
  sleep 5
done
```

Wait for the Policy Controller: this might take a while

```bash
kubectl rollout status deployment/plm-f5-waf-policy-controller \
  --namespace plm-system --timeout=180s
```

Check that everything is up and running. The pods may take a while to reach the `Running` state
```bash
kubectl get pods --namespace plm-system
```

Output should be similar to
```bash
NAME                                            READY   STATUS    RESTARTS   AGE
plm-f5-waf-compiler-service-5c7478b5b4-htc8x    1/1     Running   0          9m51s
plm-f5-waf-policy-controller-7b6f57994f-dzzwt   1/1     Running   0          9m51s
plm-f5-waf-seaweed-filer-0                      1/1     Running   0          9m8s
plm-f5-waf-seaweed-master-0                     1/1     Running   0          9m46s
plm-f5-waf-seaweed-volume-0                     1/1     Running   0          9m8s
plm-f5-waf-seaweed-volume-1                     1/1     Running   0          9m8s
plm-f5-waf-seaweed-volume-2                     1/1     Running   0          9m8s
plm-seaweedfs-operator-6789856b8b-s5qxz         1/1     Running   0          9m51s
```

Check the policy controller logs
```bash
kubectl logs --namespace plm-system deploy/plm-f5-waf-policy-controller -c policy-controller
```

Output should be similar to
```bash
INFO: security updates repo client certificates found.
INFO: HTTP client timeout configured: 5m0s
{"level":"info","ts":"2026-09-11T11:36:22Z","logger":"Policy main","msg":"Variables values","PolicyNamespace":"plm-system","FinalizerName":"appprotect.f5.com/finalizer"}
{"level":"info","ts":"2026-09-11T11:36:22Z","logger":"Policy main","msg":"WATCH_NAMESPACE not set, defaulting to all namespaces"}
{"level":"info","ts":"2026-09-11T11:36:22Z","logger":"Policy main","msg":"Watch scope: all namespaces"}
{"level":"info","ts":"2026-09-11T11:36:22Z","logger":"Policy main","msg":"Initializing S3 client for Policy Store","endpoint":"https://plm-f5-waf-seaweed-filer.plm-system.svc.cluster.local:9333","bucket":"plm-system"}
{"level":"info","ts":"2026-09-11T11:36:22Z","msg":"Creating S3 bucket (namespace)","bucket":"plm-system"}
{"level":"info","ts":"2026-09-11T11:36:22Z","msg":"S3 bucket created successfully","bucket":"plm-system"}
[...]
{"level":"info","ts":"2026-09-11T11:36:22Z","msg":"All signature processing completed successfully","correlationID":"apsignatures-1789126582-53763","workKey":"plm-system/apsignatures","attack":"","bot":"","threat":""}
{"level":"info","ts":"2026-09-11T11:36:23Z","msg":"Found latest .deb file in repository","correlationID":"query-latest-attack-signatures-1789126582978487251","packageType":"app-protect-attack-signatures","distro":"jammy","latestFile":"app-protect-attack-signatures_2026.09.09-1~jammy_amd64.deb","totalMatches":168}
{"level":"info","ts":"2026-09-11T11:36:23Z","msg":"Found latest .deb file in repository","correlationID":"query-latest-bot-signatures-1789126583202621201","packageType":"app-protect-bot-signatures","distro":"jammy","latestFile":"app-protect-bot-signatures_2026.09.09-1~jammy_amd64.deb","totalMatches":175}
{"level":"info","ts":"2026-09-11T11:36:23Z","msg":"Found latest .deb file in repository","correlationID":"query-latest-threat-campaigns-1789126583357683263","packageType":"app-protect-threat-campaigns","distro":"jammy","latestFile":"app-protect-threat-campaigns_2026.09.10-1~jammy_amd64.deb","totalMatches":165}
{"level":"info","ts":"2026-09-11T11:36:23Z","msg":"Status updated successfully","attempt":1}
{"level":"info","ts":"2026-09-11T11:36:23Z","msg":"No signature packages installed; skipping policy recompilation","correlationID":"apsignatures-1789126582-53763","workKey":"plm-system/apsignatures"}
```

## Deploy NGINX Ingress Controller

Create NGINX Ingress Controller namespace

```bash
kubectl create namespace nginx-ingress
```

Create Kubernetes secret to pull images from NGINX private registry
```bash
kubectl create secret docker-registry regcred --docker-server=private-registry.nginx.com --docker-username=`cat <nginx-one-eval.jwt>` --docker-password=none -n nginx-ingress
```

Create Kubernetes secret holding the NGINX Plus license
```bash
kubectl create secret generic license-token --from-file=license.jwt=<nginx-one-eval.jwt> --type=nginx.com/license -n nginx-ingress
```

Apply NGINX Ingress Controller custom resources (make sure the URI below references the latest available `5.x` NGINX Ingress Controller version)
```bash
kubectl apply -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.6.1/deploy/crds.yaml
```

Install NGINX Ingress Controller with F5 WAF for NGINX through its Helm chart
```bash
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update nginx-stable

helm install nic nginx-stable/nginx-ingress \
  --skip-crds \
  --set controller.image.repository="private-registry.nginx.com/nginx-ic-nap-v5/nginx-plus-ingress" \
  --set controller.image.tag="5.6.1" \
  --set controller.nginxplus=true \
  --set controller.service.type=NodePort \
  --set controller.appprotect.enable=true \
  --set controller.appprotect.v5=true \
  --set controller.appprotect.plmStorage.url="https://plm-f5-waf-seaweed-filer.plm-system.svc.cluster.local:9333" \
  --set controller.appprotect.plmStorage.credentialsSecret="plm-system/plm-f5-waf-seaweedfs-auth" \
  --set controller.appprotect.plmStorage.caSecret="plm-system/plm-f5-waf-seaweedfs-ca-cert" \
  --set controller.appprotect.plmStorage.clientSSLSecret="plm-system/plm-f5-waf-seaweedfs-client-cert" \
  --set controller.appprotect.plmStorage.insecureSkipVerify=false \
  --set controller.mgmt.licenseTokenSecretName=license-token \
  --set controller.serviceAccount.imagePullSecretName=regcred \
  -n nginx-ingress
```

Wait for the controller pod to become ready

```bash
kubectl wait --for=condition=Ready pods \
  --namespace nginx-ingress \
  --selector app.kubernetes.io/name=nginx-ingress \
  --timeout=180s
```

Check the pod status
```bash
kubectl get pods --namespace nginx-ingress
```

Output should be similar to
```bash
NAME                                            READY   STATUS    RESTARTS   AGE
nic-nginx-ingress-controller-85579b9556-4gctn   3/3     Running   0          18s
```

## Deploy the syslog server

Apply the `syslog` manifest
```bash
kubectl apply -f 2.syslog.yaml
```

Check running pods
```bash
kubectl get pods
```

Output should be similar to
```bash
NAME                      READY   STATUS    RESTARTS   AGE
syslog-794654b845-88r47   1/1     Running   0          8s
```

## WAF policy configuration and bundles creation

Create the namespace to hold policies and log profiles

```bash
kubectl create namespace security
```

Create the WAF policy and log profile in the `security` namespace

```bash
kubectl apply -f 3.waf-resources.yaml
```

Wait for WAF policy compilation to complete and bundle to become available

```bash
kubectl wait --for=jsonpath='{.status.bundle.state}'=ready \
  appolicy/dataguard-blocking --namespace security --timeout=180s
```

Wait for log profile compilation to complete and bundle to become available

```bash
kubectl wait --for=jsonpath='{.status.bundle.state}'=ready \
  aplogconf/log-default --namespace security --timeout=180s
```

Check the Policy Lifecycle Manager internal storage location for the WAF policy bundle

```bash
kubectl get appolicy dataguard-blocking --namespace security \
  --output jsonpath='State: {.status.bundle.state}{"\n"}Location: {.status.bundle.location}{"\n"}'
```

Output should be similar to
```bash
State: ready
Location: s3://security/bundles/dataguard-blocking20260911114228-dataguard-blocking-1-1789126948041783682.tgz
```

Check the Policy Lifecycle Manager internal storage location for the WAF log profile bundle
```bash
kubectl get aplogconf log-default --namespace security \
  --output jsonpath='State: {.status.bundle.state}{"\n"}Location: {.status.bundle.location}{"\n"}'
```

Output should be similar to
```bash
State: ready
Location: s3://security/bundles/log-default20260911114228.tgz
```

## Deploying a test application with WAF security enforcement

Create the WAF `Policy` object
```bash
kubectl apply -f 4.waf-policy.yaml
```

Check the policy has a `Valid` state
```bash
kubectl get policy
```

Output should be similar to
```bash
NAME         STATE   AGE
waf-policy   Valid   34s
```

Deploy the test application
```bash
kubectl apply -f 5.webapp.yaml
```

Check that the application pod is `Running`
```bash
kubectl get pods
```

Output should be similar to
```bash
NAME                      READY   STATUS    RESTARTS   AGE
syslog-794654b845-88r47   1/1     Running   0          8s
webapp-558ff5c8f6-cth9v   1/1     Running   0          3s
```

Publish the application through NGINX Ingress Controller using an `Ingress` manifest and enforcing the WAF policy through `annotations`
```bash
kubectl apply -f 6.webapp-ingress.yaml
```

Check the `Ingress` resource
```bash
kubectl describe ingress webapp-ingress
```

Output should be similar to
```bash
Name:             webapp-ingress
Labels:           <none>
Namespace:        default
Address:          
Ingress Class:    nginx
Default backend:  <default>
Rules:
  Host                Path  Backends
  ----                ----  --------
  webapp.example.com  
                      /   webapp-svc:80 (10.0.86.1:8080)
Annotations:          nginx.com/policies: waf-policy
Events:
  Type     Reason                     Age                    From                      Message
  ----     ------                     ----                   ----                      -------
  Normal   AddedOrUpdated             3m56s (x2 over 4m47s)  nginx-ingress-controller  Configuration for default/webapp-ingress was added or updated
```

WAF policy and log profile are enforced on NGINX Ingress Controller: both bundles are made available to NGINX Ingress Controller
```bash
NIC_POD=$(kubectl get pods --namespace nginx-ingress \
  --selector app.kubernetes.io/name=nginx-ingress \
  --output jsonpath='{.items[0].metadata.name}')

kubectl exec --namespace nginx-ingress $NIC_POD --container nginx-ingress -- \
  ls -ltr /etc/app_protect/bundles/
```

Output should be similar to
```bash
total 1880
-rw------- 1 nginx nginx 1917135 Sep 11 12:45 fetched_default_waf-policy_policy.tgz
-rw------- 1 nginx nginx    1652 Sep 11 12:45 fetched_default_waf-policy_log_0.tgz
```

Get NGINX Ingress Controller IP and port

```bash
export IC_IP=`kubectl get pod -l app.kubernetes.io/instance=nic -n nginx-ingress -o json|jq '.items[0].status.hostIP' -r`
export IC_HTTP_PORT=`kubectl get svc nic-nginx-ingress-controller -n nginx-ingress -o jsonpath='{.spec.ports[0].nodePort}'`
export IC_HTTPS_PORT=`kubectl get svc nic-nginx-ingress-controller -n nginx-ingress -o jsonpath='{.spec.ports[1].nodePort}'`
echo -e "NIC address: $IC_IP\nHTTP port  : $IC_HTTP_PORT\nHTTPS port : $IC_HTTPS_PORT"
```

Test application access sending a legitimate request
```bash
curl --resolve webapp.example.com:$IC_HTTP_PORT:$IC_IP \
  http://webapp.example.com:$IC_HTTP_PORT/test
```

Output should be similar to
```bash
Server address: 10.0.86.1:8080
Server name: webapp-558ff5c8f6-z9khj
Date: 11/Sep/2026:12:48:49 +0000
URI: /test
Request ID: 624fc1c8a54f5ab3655198037ba6277c
```

Test application access sending a malicious request
```bash
curl -i --resolve webapp.example.com:$IC_HTTP_PORT:$IC_IP \
  "http://webapp.example.com:$IC_HTTP_PORT/test?q=<script>alert();</script>"
```

Output should be similar to
```bash
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Connection: close
Cache-Control: no-cache
Pragma: no-cache
Content-Length: 246

<html><head><title>Request Rejected</title></head><body>The requested URL was rejected. Please consult with your administrator.<br><br>Your support ID is: 2579221527538077499<br><br><a href='javascript:history.back();'>[Go Back]</a></body></html>
```

Check WAF violation logs as received by the `syslog` pod
```bash
export SYSLOG_POD_NAME=`kubectl get pods -l app=syslog -o jsonpath='{.items[0].metadata.name}'`
kubectl exec -it $SYSLOG_POD_NAME -- cat /var/log/messages
```

Unpublish the test application through the `Ingress` resource
```bash
kubectl delete -f 6.webapp-ingress.yaml
```

Publish the test application using the `VirtualServer` Custom Resource
```bash
kubectl apply -f 7.webapp-virtualserver.yaml
```

Check the `VirtualServer` object state
```bash
kubectl describe vs webapp
```

Output should be similar to
```bash
Name:         webapp
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  k8s.nginx.org/v1
Kind:         VirtualServer
Metadata:
  Creation Timestamp:  2026-09-11T14:11:14Z
  Generation:          1
  Resource Version:    143667848
  UID:                 efd71aec-6d78-4ffe-a1f9-223471cf7fb2
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
  Normal  AddedOrUpdated  1s    nginx-ingress-controller  Configuration for default/webapp was added or updated
```

Test application access sending a legitimate request
```bash
curl --resolve webapp.example.com:$IC_HTTP_PORT:$IC_IP \
  http://webapp.example.com:$IC_HTTP_PORT/test
```

Output should be similar to
```bash
Server address: 10.0.86.1:8080
Server name: webapp-558ff5c8f6-z9khj
Date: 11/Sep/2026:12:53:39 +0000
URI: /test
Request ID: cdaa7ba80b314000f0042b5d07eafda9
```

Test application access sending a malicious request
```bash
curl -i --resolve webapp.example.com:$IC_HTTP_PORT:$IC_IP \
  "http://webapp.example.com:$IC_HTTP_PORT/test?q=<script>alert();</script>"
```

Output should be similar to
```bash
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Connection: close
Cache-Control: no-cache
Pragma: no-cache
Content-Length: 246

<html><head><title>Request Rejected</title></head><body>The requested URL was rejected. Please consult with your administrator.<br><br>Your support ID is: 7559188820450840156<br><br><a href='javascript:history.back();'>[Go Back]</a></body></html>
```

Check WAF violation logs as received by the `syslog` pod
```bash
export SYSLOG_POD_NAME=`kubectl get pods -l app=syslog -o jsonpath='{.items[0].metadata.name}'`
kubectl exec -it $SYSLOG_POD_NAME -- cat /var/log/messages
```

# Delete the lab

```bash
kubectl delete -f 7.webapp-virtualserver.yaml -f 6.webapp-ingress.yaml -f 5.webapp.yaml -f 4.waf-policy.yaml -f 3.waf-resources.yaml -f 2.syslog.yaml -f 1.plm-certs.yaml

helm uninstall nic -n nginx-ingress
kubectl delete ns nginx-ingress

helm uninstall plm -n plm-system
kubectl delete ns plm-system

helm uninstall cert-manager -n cert-manager
kubectl delete ns cert-manager

kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```
