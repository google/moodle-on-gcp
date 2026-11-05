# Configuring Cloud CDN and Dedicated Upload Pods with Functional Moodle

Enabling Google Cloud CDN in front of Moodle requires coordinated configuration across three layers:
1. **Moodle (`config.php`)**: Must emit revisioned path-based URLs (`$CFG->slasharguments = true;`) for static theme and JavaScript assets.
2. **NGINX (`nginx.conf` / `nginx.conf-template`)**:
   - Must forward `PATH_INFO` (`fastcgi_param PATH_INFO $fastcgi_path_info;`) to PHP-FPM so Moodle's revisioned PHP asset loaders (`/theme/styles.php`, `/theme/image.php`, `/theme/font.php`, `/theme/javascript.php`, `/lib/javascript.php`, `/lib/requirejs.php`) resolve their slash arguments.
   - Must strip `Set-Cookie` headers (`fastcgi_hide_header Set-Cookie;`) and emit `Cache-Control: "public, max-age=31536000, immutable"` on public versioned Moodle asset loaders—because Google Cloud CDN refuses to cache any HTTP response that includes a `Set-Cookie` header.
   - Must force `Cache-Control: "private, no-store, no-cache, must-revalidate"` on authenticated endpoints (`/pluginfile.php`, `/draftfile.php`, `/tokenpluginfile.php`, `/webservice/pluginfile.php`, `/repository/`, `/login/`) so private student submissions, course files, and login sessions are never cached at the CDN edge.
3. **GKE `BackendConfig` (`6-backendconfig/ingress-backendconfig-nginx.yaml` and `6-backendconfig/ingress-backendconfig-nginx-uploads.yaml`)**:
   - The main `ingress-backendconfig` uses `cacheMode: USE_ORIGIN_HEADERS` (with `includeHost: true`, `includeProtocol: true`, `includeQueryString: true`, `negativeCaching: false`, and `serveWhileStale: 86400`), ensuring Cloud CDN strictly honors the `Cache-Control` headers emitted by NGINX rather than blindly caching `.pdf` or image URLs served through `/pluginfile.php`.
   - The dedicated uploads backend (`ingress-backendconfig-uploads`) disables Cloud CDN (`cdn.enabled: false`) and extends `timeoutSec: 3600` to support large file uploads (`/repository/repository_ajax.php` and `/repository/draftfiles_ajax.php`).

---

## 1. How Cloud CDN Caching Works with Moodle 5.2+

| Endpoint Pattern | Handled By | `Set-Cookie` Header | `Cache-Control` Header | Cloud CDN Behavior |
| :--- | :--- | :--- | :--- | :--- |
| `/theme/styles.php/<theme>/<rev>/all` | NGINX -> PHP-FPM | Stripped (`fastcgi_hide_header Set-Cookie`) | `public, max-age=31536000, immutable` | **Cached at Edge (1 year; busted automatically on Moodle theme revision change)** |
| `/theme/image.php`, `/theme/font.php`, `/theme/javascript.php` | NGINX -> PHP-FPM | Stripped (`fastcgi_hide_header Set-Cookie`) | `public, max-age=31536000, immutable` | **Cached at Edge** |
| `/lib/javascript.php/<rev>/...`, `/lib/requirejs.php/<rev>/...` | NGINX -> PHP-FPM | Stripped (`fastcgi_hide_header Set-Cookie`) | `public, max-age=31536000, immutable` | **Cached at Edge** |
| Static files (`*.jpg`, `*.png`, `*.css`, `*.js`, `*.woff2`, `*.svg`) | NGINX directly | None | `public, max-age=2592000` | **Cached at Edge (30 days)** |
| `/pluginfile.php/...`, `/draftfile.php/...`, `/tokenpluginfile.php/...` | NGINX -> PHP-FPM (+ `X-Accel-Redirect`) | Preserved | `private, no-store, no-cache, must-revalidate` | **Never cached by Cloud CDN** |
| `/repository/repository_ajax.php`, `/repository/draftfiles_ajax.php` | Routed to `moodle-service-uploads` (`ingress-backendconfig-uploads`) | Preserved | `private, no-store, no-cache, must-revalidate` | **Bypassed (`cdn.enabled: false`, `timeoutSec: 3600`)** |

---

## 2. Applying the BackendConfig and Dedicated Upload Manifests

1. Apply both `BackendConfig` resources (main web traffic with Cloud CDN + dedicated uploads without Cloud CDN):

```bash
kubectl apply -f 6-backendconfig/ingress-backendconfig-nginx.yaml
kubectl apply -f 6-backendconfig/ingress-backendconfig-nginx-uploads.yaml
```

2. Apply the main and dedicated upload ConfigMaps, Deployments, Services, and HPAs:

```bash
kubectl apply -f 5a-deployment-no-helm/moodle-configmap-nginx.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-deployment-nginx.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-service.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-service-uploads.yaml
kubectl apply -f 9-hpa/moodle-hpa.yaml
kubectl apply -f 9-hpa/moodle-uploads-hpa.yaml
```

3. Apply the Ingress resource (`8-ingress/gce-ingress-external.yaml`), which routes `/repository/repository_ajax.php` and `/repository/draftfiles_ajax.php` to `moodle-service-uploads` and all other traffic (`/*`) to `moodle`:

```bash
kubectl apply -f 8-ingress/gce-ingress-external.yaml
```

---

## 3. Verifying Cloud CDN Cache Hits

Once the Google Cloud Load Balancer and Ingress are provisioned, verify that Moodle's revisioned theme/JS endpoints return `Cache-Control: public, max-age=31536000, immutable` without `Set-Cookie` and produce `Age` / cache-hit headers from Cloud CDN:

```bash
curl -I "https://moodle.<YOUR-LB-EXTERNAL-IP>.nip.io/theme/styles.php/boost/1/all"
```

And verify that authenticated file endpoints emit `Cache-Control: private, no-store, no-cache, must-revalidate`:

```bash
curl -I "https://moodle.<YOUR-LB-EXTERNAL-IP>.nip.io/pluginfile.php"
```
