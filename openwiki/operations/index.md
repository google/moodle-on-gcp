# Files

- [Cloud CDN for Moodle, NGINX/PHP-FPM Tuning, and Ingress Routing](cloud-cdn-and-ingress.md) - Integration between Google Cloud CDN (USE_ORIGIN_HEADERS), NGINX X-Accel-Redirect (^~ prefix protection), fastcgi_request_buffering off for 10GB+ streaming uploads, Moodle slasharguments, Set-Cookie stripping on public assets, private file protection, and Ingress routing.
- [GKE Deployments, 10GB Upload Pod Isolation, ProxySQL, and Horizontal Pod Autoscaling](gke-deployments-and-uploads-isolation.md) - Kubernetes Deployment architecture for Moodle 5.2.4, Guaranteed QoS rightsizing, isolated 10GB+ upload pods (disk-backed /tmp, PHP_FPM_MAX_CHILDREN=1), optional Secrets, ProxySQL connection multiplexing, and HPA policies.
