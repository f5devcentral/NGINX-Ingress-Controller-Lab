# Lab deployment

See the [prerequisites](/README.md#getting-started)

This deployment is for NGINX Ingress Controller and F5 WAF for NGINX with precompiled WAF policies and log profiles

## Installing

1. Clone this repository and `cd` into it
```code
git clone https://github.com/f5devcentral/NGINX-Ingress-Controller-Lab.git
cd NGINX-Ingress-Controller-Lab
```

2. Create NGINX Ingress Controller namespace

```code
kubectl create namespace nginx-ingress
```

3. Create Kubernetes secret to pull images from NGINX private registry

```code
kubectl create secret docker-registry regcred --docker-server=private-registry.nginx.com --docker-username=`cat <nginx-one-eval.jwt>` --docker-password=none -n nginx-ingress
```

Note: `<nginx-one-eval.jwt>` is the path and filename of your `nginx-one-eval.jwt` file

4. Create Kubernetes secret holding the NGINX Plus license

```code
kubectl create secret generic license-token --from-file=license.jwt=<nginx-one-eval.jwt> --type=nginx.com/license -n nginx-ingress
```

Note: `<nginx-one-eval.jwt>` is the path and filename of your `nginx-one-eval.jwt` file

5. List available NGINX Ingress Controller docker images that include F5 WAF for NGINX

```code
curl -s https://private-registry.nginx.com/v2/nginx-ic-nap-v5/nginx-plus-ingress/tags/list --key <nginx-one-eval.key> --cert <nginx-one-eval.crt> | jq
```

Note: `<nginx-one-eval.key>` and `<nginx-one-eval.key>` are the path and filename of your `nginx-one-eval.crt` and `nginx-one-eval.crt` files respectively

Pick the latest version (`5.7.0` at the time of writing)

6. Apply NGINX Ingress Controller custom resources (make sure the URI below references the latest available `5.x` NGINX Ingress Controller version)
```code
kubectl apply -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.7.0/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.7.0/deploy/crds-nap-waf.yaml
```

7. Create the PVCs to store compiled WAF policy bundles and logging profiles
```code
kubectl apply -f ./deployment/pvcs.yaml
```

8. Install NGINX Ingress Controller with F5 WAF for NGINX through its Helm chart (set `nginx.image.tag` to the latest `5.x` available NGINX Ingress Controller version and adjust the chart version accordingly)

```code
helm install nic oci://ghcr.io/nginx/charts/nginx-ingress \
  --version 2.8.0 \
  --set controller.image.repository=private-registry.nginx.com/nginx-ic-nap-v5/nginx-plus-ingress \
  --set controller.image.tag=5.7.0 \
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

9. Check NGINX Ingress Controller pod status

```code
kubectl get pods -n nginx-ingress
```

Pod should be in the `Running` state

```code
NAME                                           READY   STATUS    RESTARTS   AGE
nic-nginx-ingress-controller-fc7546d97-9lcbk   3/3     Running   0          22s
```

10. Check NGINX Ingress Controller logs

```code
kubectl logs -l app.kubernetes.io/instance=nic -n nginx-ingress -c nginx-ingress
```

Output should be similar to the following

```code
2026/10/14 14:34:49 [notice] 19#19: exit
I20261014 14:34:49.782945   1 main.go:116] Event(v1.ObjectReference{Kind:"Pod", Namespace:"nginx-ingress", Name:"nic-nginx-ingress-controller-66d8c95784-tt9vp", UID:"376fbc0c-c024-4c6d-980e-671df1eb6781", APIVersion:"v1", ResourceVersion:"151449156", FieldPath:""}): type: 'Normal' reason: 'SecretUpdated' the special Secret nginx-ingress/license-token was updated
I20261014 14:34:49.783176   1 main.go:116] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"nginx-ingress", Name:"nic-nginx-ingress", UID:"07fe718f-a7b5-4d5c-aa15-ef2e5c29c7bf", APIVersion:"v1", ResourceVersion:"151449123", FieldPath:""}): type: 'Normal' reason: 'Updated' ConfigMap nginx-ingress/nic-nginx-ingress updated without error
I20261014 14:34:49.783207   1 main.go:116] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"nginx-ingress", Name:"nic-nginx-ingress-mgmt", UID:"8a2cfc46-41d7-44ea-af71-a5ef212562f2", APIVersion:"v1", ResourceVersion:"151449124", FieldPath:""}): type: 'Normal' reason: 'Updated' MGMT ConfigMap nginx-ingress/nic-nginx-ingress-mgmt updated without error
2026/10/14 14:34:49 [notice] 13#13: signal 17 (SIGCHLD) received from 19
2026/10/14 14:34:49 [notice] 13#13: worker process 19 exited with code 0
2026/10/14 14:34:49 [notice] 13#13: signal 29 (SIGIO) received
2026/10/14 14:34:49 [notice] 13#13: signal 17 (SIGCHLD) received from 18
2026/10/14 14:34:49 [notice] 13#13: worker process 18 exited with code 0
2026/10/14 14:34:49 [notice] 13#13: signal 29 (SIGIO) received
```

11. Check Kubernetes service status

```code
kubectl get svc -n nginx-ingress
```

NGINX Ingress Controller should be listening on TCP ports 80 and 443

```code
NAME                           TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
nic-nginx-ingress-controller   NodePort   10.99.199.74   <none>        80:32507/TCP,443:31477/TCP   71s
```

12. Check the `ingressclass`

```code
kubectl get ingressclass
```

The `nginx` ingressclass should be available

```code
NAME    CONTROLLER                     PARAMETERS   AGE
nginx   nginx.org/ingress-controller   <none>       85s
```

## Build the WAF compiler

1. List available F5 WAF for NGINX compiler versions
```code
curl -s https://private-registry.nginx.com/v2/nap/waf-compiler/tags/list --key <nginx-one-eval.key> --cert <nginx-one-eval.crt> | jq
```

2. Set up Docker to authenticate to the private registry
```code
sudo mkdir -p /etc/docker/certs.d/private-registry.nginx.com
sudo cp <nginx-one-eval.crt> /etc/docker/certs.d/private-registry.nginx.com/client.cert
sudo cp <nginx-one-eval.key> /etc/docker/certs.d/private-registry.nginx.com/client.key
```

3. Build the F5 WAF for NGINX compiler (`5.16.0` at the time of writing):
```code
docker build -f deployment/Dockerfile --no-cache --platform linux/amd64 \
  --secret id=nginx-crt,src=<nginx-one-eval.crt> \
  --secret id=nginx-key,src=<nginx-one-eval.key> \
  -t waf-compiler-5.16.0:custom .
```

4. The output should be similar to the following
```code
 => [internal] load build definition from Dockerfile                                                                                                                                                                           0.3s
 => => transferring dockerfile: 1.36kB                                                                                                                                                                                         0.0s
[...]
 => exporting to image                                                                                                                                                                                                         0.6s
 => => exporting layers                                                                                                                                                                                                        0.4s
 => => writing image sha256:3f345ec5d1ad3d08cbed5082e209e916cda912dbcd32d24b63cc2f5ef16862cd                                                                                                                                   0.0s
 => => naming to docker.io/library/waf-compiler-5.16.0:custom                                                                                                                                                                  0.1s
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
kubectl delete -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.7.0/deploy/crds.yaml
kubectl delete -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.7.0/deploy/crds-nap-waf.yaml
```
