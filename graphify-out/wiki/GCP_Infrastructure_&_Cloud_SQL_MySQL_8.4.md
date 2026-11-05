# GCP Infrastructure & Cloud SQL MySQL 8.4

> 9 nodes

## Key Concepts

- **Service moodle (ClusterIP 80->8080, NEG & ingress-backendconfig)** (4 connections) — `5a-deployment-no-helm/moodle-service.yaml`
- **Service moodle-service-uploads (ClusterIP 80->8080, NEG & ingress-backendconfig-uploads)** (4 connections) — `5a-deployment-no-helm/moodle-service-uploads.yaml`
- **Ingress moodle-ingress (GCE External HTTP(S) Load Balancer, Path Routing for Ajax Uploads)** (4 connections) — `8-ingress/gce-ingress-external.yaml`
- **BackendConfig ingress-backendconfig (300s Timeout, /healthz, Cloud CDN USE_ORIGIN_HEADERS)** (2 connections) — `6-backendconfig/ingress-backendconfig-nginx.yaml`
- **Ingress moodle-ingress (Optional NGINX Ingress Controller with 512m Body & 3600s Timeout)** (2 connections) — `8-ingress/nginx-ingress-external-this-is-optional.yaml`
- **BackendConfig ingress-backendconfig-uploads (3600s Timeout, /healthz, Cloud CDN Disabled)** (1 connections) — `6-backendconfig/ingress-backendconfig-nginx-uploads.yaml`
- **FrontendConfig moodle-ingress-frontendconfig-https (301 HTTP-to-HTTPS Redirect)** (1 connections) — `7-ssl-certificate-and-redirect/frontendconfig-redirect-http-to-https.yaml`
- **ManagedCertificate moodle-google-managed-certificate** (1 connections) — `7-ssl-certificate-and-redirect/google-managed-ssl-certificate.yaml`
- **Cloud CDN USE_ORIGIN_HEADERS Policy (Caches Static/Versioned Moodle Assets, Protects Private Files)** (1 connections) — `6-backendconfig/ingress-backendconfig-nginx.yaml`

## Relationships

- [Storage Modalities (Filestore & Regional PD)](Storage_Modalities_Filestore_&_Regional_PD.md) (2 shared connections)

## Source Files

- `5a-deployment-no-helm/moodle-service-uploads.yaml`
- `5a-deployment-no-helm/moodle-service.yaml`
- `6-backendconfig/ingress-backendconfig-nginx-uploads.yaml`
- `6-backendconfig/ingress-backendconfig-nginx.yaml`
- `7-ssl-certificate-and-redirect/frontendconfig-redirect-http-to-https.yaml`
- `7-ssl-certificate-and-redirect/google-managed-ssl-certificate.yaml`
- `8-ingress/gce-ingress-external.yaml`
- `8-ingress/nginx-ingress-external-this-is-optional.yaml`

## Audit Trail

- EXTRACTED: 11 (100%)
- INFERRED: 0 (0%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [index](index.md) to navigate.*