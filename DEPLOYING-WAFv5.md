# Lab deployment

See the [prerequisites](/README.md#getting-started)

This deployment is for NGINX Ingress Controller and F5 WAF for NGINX with precompiled WAF policies and log profiles

## Installing

1. Create NGINX Ingress Controller namespace

```code
kubectl create namespace nginx-ingress
```

2. Create Kubernetes secret to pull images from NGINX private registry

```code
kubectl create secret docker-registry regcred --docker-server=private-registry.nginx.com --docker-username=`cat <nginx-one-eval.jwt>` --docker-password=none -n nginx-ingress
```

Note: `<nginx-one-eval.jwt>` is the path and filename of your `nginx-one-eval.jwt` file

3. Create Kubernetes secret holding the NGINX Plus license

```code
kubectl create secret generic license-token --from-file=license.jwt=<nginx-one-eval.jwt> --type=nginx.com/license -n nginx-ingress
```

Note: `<nginx-one-eval.jwt>` is the path and filename of your `nginx-one-eval.jwt` file

4. List available NGINX Ingress Controller docker images that include NGINX App Protect WAF

```code
curl -s https://private-registry.nginx.com/v2/nginx-ic-nap-v5/nginx-plus-ingress/tags/list --key <nginx-one-eval.key> --cert <nginx-one-eval.crt> | jq
```

Note: `<nginx-one-eval.key>` and `<nginx-one-eval.key>` are the path and filename of your `nginx-one-eval.crt` and `nginx-one-eval.crt` files respectively

Pick the latest version (`5.4.2` at the time of writing)

5. Apply NGINX Ingress Controller custom resources (make sure the URI below references the latest available `5.x` NGINX Ingress Controller version)
```code
kubectl apply -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.4.2/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.4.2/deploy/crds-nap-waf.yaml
```

6. Create the PVCs to store compiled WAF policy bundles and logging profiles
```code
kubectl apply -f ./deployment/pvcs.yaml
```

7. Install NGINX Ingress Controller with NGINX App Protect through its Helm chart (set `nginx.image.tag` to the latest `5.x` available NGINX Ingress Controller version and adjust the chart version accordingly)

```code
helm install nic oci://ghcr.io/nginx/charts/nginx-ingress \
  --version 2.5.2 \
  --set controller.image.repository=private-registry.nginx.com/nginx-ic-nap-v5/nginx-plus-ingress \
  --set controller.image.tag=5.4.2 \
  --set controller.nginxplus=true \
  --set controller.appprotect.enable=true \
  --set controller.appprotect.v5=true \
  --set-json 'controller.appprotect.volumes=[{"name":"app-protect-bd-config","emptyDir":{}},{"name":"app-protect-config","emptyDir":{}},{"name":"app-protect-bundles","persistentVolumeClaim":{"claimName":"task-pv-claim"}}]' \
  --set controller.volumeMounts[0].name=app-protect-bundles \
  --set controller.volumeMounts[0].mountPath="/etc/app_protect/bundles/" \
  --set controller.serviceAccount.imagePullSecretName=regcred \
  --set controller.mgmt.licenseTokenSecretName=license-token \
  --set controller.service.type=NodePort \
  -n nginx-ingress
```

8. Check NGINX Ingress Controller pod status

```code
kubectl get pods -n nginx-ingress
```

Pod should be in the `Running` state

```code
NAME                                           READY   STATUS    RESTARTS   AGE
nic-nginx-ingress-controller-8b75b59bf-5zcc2   3/3     Running   0          3m28s
```

9. Check NGINX Ingress Controller logs

```code
kubectl logs -l app.kubernetes.io/instance=nic -n nginx-ingress -c nginx-ingress
```

Output should be similar to

```code
I20260409 15:57:09.501899   1 main.go:112] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"nginx-ingress", Name:"nic-nginx-ingress", UID:"72830f00-d69c-400c-9f11-611df7a9b418", APIVersion:"v1", ResourceVersion:"108817766", FieldPath:""}): type: 'Normal' reason: 'Updated' ConfigMap nginx-ingress/nic-nginx-ingress updated without error
I20260409 15:57:09.501926   1 main.go:112] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"nginx-ingress", Name:"nic-nginx-ingress-mgmt", UID:"4bfd2675-012e-43cb-a7a2-2aa57da79561", APIVersion:"v1", ResourceVersion:"108817764", FieldPath:""}): type: 'Normal' reason: 'Updated' MGMT ConfigMap nginx-ingress/nic-nginx-ingress-mgmt updated without error
2026/04/09 15:57:09 [notice] 15#15: signal 17 (SIGCHLD) received from 20
2026/04/09 15:57:09 [notice] 15#15: worker process 20 exited with code 0
2026/04/09 15:57:09 [notice] 15#15: signal 29 (SIGIO) received
2026/04/09 15:57:09 [notice] 15#15: signal 17 (SIGCHLD) received from 21
2026/04/09 15:57:09 [notice] 15#15: worker process 21 exited with code 0
2026/04/09 15:57:09 [notice] 15#15: signal 29 (SIGIO) received
BD_MISC|NOTICE|Apr 09 15:57:25.411|0036|/builds/t1_xXBa_N/12/waf/waf-general/secore/bd/bd/temp_func.c:2874|UMU: 0 0 || 0 0 0 0 0 0 0 0 0 0 0 0 || 0 0 0 0 0 0 0 
BD_MISC|NOTICE|Apr 09 15:57:25.411|0036|/builds/t1_xXBa_N/12/waf/waf-general/secore/bd/bd/temp_func.c:2875|UMU: total     0 (  0Kb) VM (486M) RSS ( 49M) SWAP (  0M) Cache (0) trans     0
```

10. Check Kubernetes service status

```code
kubectl get svc -n nginx-ingress
```

NGINX Ingress Controller should be listening on TCP ports 80 and 443

```code
NAME                           TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
nic-nginx-ingress-controller   NodePort   10.111.219.126   <none>        80:30106/TCP,443:31131/TCP   4m25s
```

10. Check the `ingressclass`

```code
kubectl get ingressclass
```

The `nginx` ingressclass should be available

```code
NAME    CONTROLLER                     PARAMETERS   AGE
nginx   nginx.org/ingress-controller   <none>       4m45s
```

## Build the WAF compiler

1. Clone this repository and `cd` into it
```code
git clone https://github.com/f5devcentral/NGINX-Ingress-Controller-Lab.git
cd NGINX-Ingress-Controller-Lab
```

2. List available F5 WAF for NGINX compiler versions
```code
curl -s https://private-registry.nginx.com/v2/nap/waf-compiler/tags/list --key <nginx-one-eval.key> --cert <nginx-one-eval.crt> | jq
```

3. Set up Docker to authenticate to the private registry
```code
sudo mkdir -p /etc/docker/certs.d/private-registry.nginx.com
sudo cp <nginx-one-eval.crt> /etc/docker/certs.d/private-registry.nginx.com/client.cert
sudo cp <nginx-one-eval.key> /etc/docker/certs.d/private-registry.nginx.com/client.key
```

4. Build the F5 WAF for NGINX compiler (`5.11.2` at the time of writing):
```code
docker build -f deployment/Dockerfile --no-cache --platform linux/amd64 \
  --secret id=nginx-crt,src=<nginx-one-eval.crt> \
  --secret id=nginx-key,src=<nginx-one-eval.key> \
  -t waf-compiler-5.11.2:custom .
```

5. The output should be similar to
```code
[+] Building 67.8s (9/9) FINISHED                                                                                                                                                  docker:default
 => [internal] load build definition from Dockerfile                                                                                                                                         0.0s
 => => transferring dockerfile: 1.36kB                                                                                                                                                       0.0s
 => resolve image config for docker-image://docker.io/docker/dockerfile:1                                                                                                                    0.7s
 => [auth] docker/dockerfile:pull token for registry-1.docker.io                                                                                                                             0.0s
 => CACHED docker-image://docker.io/docker/dockerfile:1@sha256:b6afd42430b15f2d2a4c5a02b919e98a525b785b1aaff16747d2f623364e39b6                                                              0.0s
 => [internal] load metadata for private-registry.nginx.com/nap/waf-compiler:5.11.2                                                                                                          0.3s
 => [internal] load .dockerignore                                                                                                                                                            0.0s
 => => transferring context: 2B                                                                                                                                                              0.0s
 => CACHED [stage-0 1/2] FROM private-registry.nginx.com/nap/waf-compiler:5.11.2@sha256:aee2af5e9b7a8e2f6b5e3b37e42623514d97470ee033fed514aad61182e0bc94                                     0.0s
 => [stage-0 2/2] RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644     --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644     ap  65.9s
 => exporting to image                                                                                                                                                                       0.3s 
 => => exporting layers                                                                                                                                                                      0.2s 
 => => writing image sha256:4dcfcaac1acad8934a193b86c6b46152e72db1fa99cdd81db74d9a7996820792                                                                                                 0.0s 
 => => naming to docker.io/library/waf-compiler-5.11.2:custom                                                                                                                                0.0s 
```

## Uninstalling

1. Uninstall NGINX Ingress Controller through its Helm chart

```code
helm uninstall nic -n nginx-ingress
```

2. Delete the namespace

```code
kubectl delete namespace nginx-ingress
```

3. Delete custom resources

```code
kubectl delete -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.4.2/deploy/crds.yaml
kubectl delete -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.4.2/deploy/crds-nap-waf.yaml
```
