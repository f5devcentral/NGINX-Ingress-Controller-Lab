# Lab deployment

See the [prerequisites](/README.md#getting-started)

This deployment is for NGINX Ingress Controller and F5 WAF for NGINX without precompiled WAF policies

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

5. List available NGINX Ingress Controller docker images that include NGINX App Protect WAF

```code
curl -s https://private-registry.nginx.com/v2/nginx-ic-nap/nginx-plus-ingress/tags/list --key <nginx-one-eval.key> --cert <nginx-one-eval.crt> | jq
```

Note: `<nginx-one-eval.key>` and `<nginx-one-eval.key>` are the path and filename of your `nginx-one-eval.crt` and `nginx-one-eval.crt` files respectively

Pick the latest version (`5.5.3` at the time of writing)

6. Apply NGINX Ingress Controller custom resources (make sure the URI below references the latest available `5.x` NGINX Ingress Controller version)

```code
kubectl apply -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.5.3/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.5.3/deploy/crds-nap-waf.yaml
```

7. Install NGINX Ingress Controller with NGINX App Protect through its Helm chart (set `nginx.image.tag` to the latest `5.x` available NGINX Ingress Controller version)

```code
helm install nic oci://ghcr.io/nginx/charts/nginx-ingress \
  --version 2.6.3 \
  --set controller.image.repository=private-registry.nginx.com/nginx-ic-nap/nginx-plus-ingress \
  --set controller.image.tag=5.5.3 \
  --set controller.nginxplus=true \
  --set controller.appprotect.enable=true \
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
NAME                                            READY   STATUS    RESTARTS   AGE
nic-nginx-ingress-controller-7575f4d76f-888v7   1/1     Running   0          62s
```

9. Check NGINX Ingress Controller logs

```code
kubectl logs -l app.kubernetes.io/instance=nic -n nginx-ingress -c nginx-ingress
```

Output should be similar to
```code
2026/07/16 08:32:24 [notice] 19#19: exit
2026/07/16 08:32:24 [notice] 20#20: exit
I20260716 08:32:24.114052   1 main.go:110] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"nginx-ingress", Name:"nic-nginx-ingress", UID:"2ba49678-5a05-4998-861b-68a26558fa64", APIVersion:"v1", ResourceVersion:"130407148", FieldPath:""}): type: 'Normal' reason: 'Updated' ConfigMap nginx-ingress/nic-nginx-ingress updated without error
I20260716 08:32:24.114083   1 main.go:110] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"nginx-ingress", Name:"nic-nginx-ingress-mgmt", UID:"7cb756bc-f6fb-4312-b14c-a89552bb7261", APIVersion:"v1", ResourceVersion:"130407147", FieldPath:""}): type: 'Normal' reason: 'Updated' MGMT ConfigMap nginx-ingress/nic-nginx-ingress-mgmt updated without error
2026/07/16 08:32:24 [notice] 13#13: signal 17 (SIGCHLD) received from 19
2026/07/16 08:32:24 [notice] 13#13: worker process 19 exited with code 0
2026/07/16 08:32:24 [notice] 13#13: signal 29 (SIGIO) received
2026/07/16 08:32:24 [notice] 13#13: signal 17 (SIGCHLD) received from 20
2026/07/16 08:32:24 [notice] 13#13: worker process 20 exited with code 0
2026/07/16 08:32:24 [notice] 13#13: signal 29 (SIGIO) received
```

10. Check Kubernetes service status

```code
kubectl get svc -n nginx-ingress
```

NGINX Ingress Controller should be listening on TCP ports 80 and 443

```code
NAME                           TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
nic-nginx-ingress-controller   NodePort   10.109.220.151   <none>        80:31233/TCP,443:31404/TCP   86s
```

11. Check the `ingressclass`

```code
kubectl get ingressclass
```

The `nginx` ingressclass should be available

```code
NAME    CONTROLLER                     PARAMETERS   AGE
nginx   nginx.org/ingress-controller   <none>       101s
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
kubectl delete -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.5.3/deploy/crds.yaml
kubectl delete -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.5.3/deploy/crds-nap-waf.yaml
```
