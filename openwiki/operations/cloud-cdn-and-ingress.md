---
type: operations
title: Cloud CDN com Moodle Funcional, Tuning NGINX/PHP-FPM e Ingress
description: Integração entre Google Cloud CDN (USE_ORIGIN_HEADERS), slasharguments no Moodle, ocultação de Set-Cookie em assets públicos no NGINX, proteção de /pluginfile.php e roteamento de Ingress.
tags: [cloud-cdn, nginx, php-fpm, ingress, backendconfig, caching, moodle]
verified:
  - by: openwiki/0.5.1
    at: 2026-11-05T11:15:21.468Z
sources:
  - id: openwiki-source-f1819a6d2572649fd572f139
    resource: repo://4-moodle-image-builder/base/etc/nginx/nginx.conf-template
  - id: openwiki-source-5bcc07e16214acd285260e87
    resource: repo://4-moodle-image-builder/base/etc/php83/php-fpm.d/moodle.conf
  - id: openwiki-source-4bd036642052c68bf1eeafa3
    resource: repo://4-moodle-image-builder/config.php.template
  - id: openwiki-source-e6ff537d174c1cfa3db7b5c4
    resource: repo://6-backendconfig/ingress-backendconfig-nginx-uploads.yaml
  - id: openwiki-source-6f76a6982206d118a6850d9c
    resource: repo://6-backendconfig/ingress-backendconfig-nginx.yaml
  - id: openwiki-source-93c77b17f1a30ce2778ab508
    resource: repo://8-ingress/gce-ingress-external.yaml
generated: { by: "antigravity", at: "2026-11-05T11:15:21.468Z" }
---

# Cloud CDN com Moodle Funcional, Tuning NGINX/PHP-FPM e Ingress

Para que o Google Cloud CDN funcione corretamente diante do Moodle 5.2+ sem quebrar sessões autenticadas nem expor arquivos privados de cursos, a configuração atua de forma coordenada em três camadas: `4-moodle-image-builder/config.php.template`, `4-moodle-image-builder/base/etc/nginx/nginx.conf-template` e `6-backendconfig/ingress-backendconfig-nginx.yaml`.

<!-- openwiki: mermaid parse failed and this diagram was converted to a text fence so it does not break rendering. Fix the diagram source and restore the mermaid fence. Parser error: Heuristic: an unescaped angle bracket inside a label breaks rendering; rephrase the label. -->
```text
sequenceDiagram
    participant User as Navegador / Aluno
    participant CDN as Google Cloud LB + Cloud CDN
    participant Ing as GKE Ingress (moodle-ingress)
    participant Web as Service: moodle (NGINX + PHP 8.3)
    participant Upl as Service: moodle-service-uploads

    User->>CDN: GET /theme/styles.php/boost/1730800000/all
    alt Cache Hit na Borda
        CDN-->>User: 200 OK (Cache-Control: public, max-age=31536000, immutable)
    else Cache Miss
        CDN->>Ing: Encaminha para Service moodle
        Ing->>Web: FastCGI com PATH_INFO ($CFG->slasharguments = true)
        Web-->>CDN: 200 OK (fastcgi_hide_header Set-Cookie + Cache-Control: public, immutable)
        CDN-->>User: 200 OK (Armazenado no Cloud CDN)
    end

    User->>CDN: GET /pluginfile.php/42/mod_resource/content/1/prova.pdf
    CDN->>Web: Bypass de Cache (USE_ORIGIN_HEADERS)
    Web-->>User: 200 OK (Cache-Control: private, no-store, no-cache, must-revalidate)

    User->>CDN: POST /repository/repository_ajax.php (Upload 512MB)
    CDN->>Upl: Roteado para moodle-service-uploads (cdn.enabled: false, timeoutSec: 3600)
    Upl-->>User: 200 OK (Upload concluído)
```

## 1. Habilitação de `slasharguments` e `PATH_INFO` no Moodle e NGINX

O Moodle entrega folhas de estilo, pacotes JavaScript/AMD, fontes e imagens de tema por meio de scripts PHP versionados (`/theme/styles.php`, `/theme/image.php`, `/theme/font.php`, `/theme/javascript.php`, `/lib/javascript.php`, `/lib/requirejs.php`).

1. Em `4-moodle-image-builder/config.php.template`, a diretiva `$CFG->slasharguments = true;` instrui o Moodle a gerar URLs baseadas em caminho com o identificador de revisão embutido (ex.: `/theme/styles.php/boost/1730800000/all`).
2. Em `4-moodle-image-builder/base/etc/nginx/nginx.conf-template`, todos os blocos FastCGI executam `fastcgi_split_path_info ^(.+\.php)(/.+)$;` e injetam explicitamente `fastcgi_param PATH_INFO $fastcgi_path_info;` e `fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;`, requisito obrigatório no NGINX sobre Alpine para que o Moodle processe `slasharguments` e pacotes SCORM.

## 2. Regras de Cache do NGINX para o Cloud CDN

O Google Cloud CDN **não armazena em cache respostas HTTP que contenham o cabeçalho `Set-Cookie`**. Além disso, usar `CACHE_ALL_STATIC` de forma indiscriminada no Cloud CDN representaria risco de cachear arquivos privados de cursos servidos por `/pluginfile.php/.../documento.pdf` (cuja URL termina em `.pdf`).

Por isso, `4-moodle-image-builder/base/etc/nginx/nginx.conf-template` separa os endpoints PHP do Moodle em três blocos distintos:

1. **Loaders Públicos Versionados do Moodle (`/theme/(styles|image|font|javascript)\.php` e `/lib/(javascript|requirejs)\.php`)**:
   - Remove `Set-Cookie`, `Pragma` e `Cache-Control` emitidos pelo PHP-FPM (`fastcgi_hide_header Set-Cookie; fastcgi_hide_header Pragma; fastcgi_hide_header Cache-Control;`).
   - Adiciona `add_header Cache-Control "public, max-age=31536000, immutable";`, permitindo que o Cloud CDN armazene os recursos na borda por até 1 ano (com invalidação automática sempre que o Moodle incrementar a revisão do tema/JS).
2. **Endpoints Autenticados de Arquivos e Login (`/pluginfile.php`, `/draftfile.php`, `/tokenpluginfile.php`, `/webservice/pluginfile.php`, `/repository/`, `/login/`)**:
   - Força `add_header Cache-Control "private, no-store, no-cache, must-revalidate" always;`, garantindo que arquivos privados de cursos, rascunhos de usuários e respostas de autenticação jamais sejam cacheados pelo Cloud CDN.
3. **Arquivos Estáticos Diretos (`*.jpg`, `*.png`, `*.css`, `*.js`, `*.svg`, `*.woff2`, etc.)**:
   - Define `expires 30d; add_header Cache-Control "public, max-age=2592000";`.

## 3. Configuração dos `BackendConfig` (`USE_ORIGIN_HEADERS` vs. `uploads`)

- **`6-backendconfig/ingress-backendconfig-nginx.yaml` (`ingress-backendconfig`)**:
  - Habilita o Cloud CDN (`cdn.enabled: true`) com `cacheMode: USE_ORIGIN_HEADERS`, `negativeCaching: false`, `serveWhileStale: 86400` e `cachePolicy` com `includeHost: true`, `includeProtocol: true` e `includeQueryString: true`.
  - Com `USE_ORIGIN_HEADERS`, o Cloud CDN respeita estritamente os cabeçalhos `Cache-Control` emitidos pelo NGINX.
- **`6-backendconfig/ingress-backendconfig-nginx-uploads.yaml` (`ingress-backendconfig-uploads`)**:
  - Desabilita o Cloud CDN (`cdn.enabled: false`) e eleva `timeoutSec: 3600` e `drainingTimeoutSec: 60` para suportar uploads longos sem timeout de 30s/300s no Load Balancer.

## 4. Tuning de NGINX e PHP-FPM 8.3 e Roteamento no Ingress

- **NGINX (`4-moodle-image-builder/base/etc/nginx/nginx.conf-template`)**:
  - `worker_processes auto;`, `server_tokens off;`, `keepalive_timeout 65;`, `fastcgi_buffers 16 16k;`, `fastcgi_buffer_size 32k;`, `client_max_body_size 50M;` (sobrescrito para `512M` nos pods de upload) e `gzip_disable "msie6";`.
- **PHP-FPM 8.3 (`4-moodle-image-builder/base/etc/php83/php-fpm.d/moodle.conf` e `php.ini-template`)**:
  - `pm = ondemand`, `pm.max_children = 8`, `pm.process_idle_timeout = 10s`, `pm.max_requests = 500`, `request_terminate_timeout = 3600`, `memory_limit = 256M` (nos pods web gerais) e `expose_php = Off`.
- **Roteamento de Ingress (`8-ingress/gce-ingress-external.yaml` e `8-ingress/nginx-ingress-external-this-is-optional.yaml`)**:
  - As rotas `/repository/repository_ajax.php` e `/repository/draftfiles_ajax.php` (`pathType: Exact`) são direcionadas ao serviço `moodle-service-uploads`, enquanto `/*` (ou `/`) é atendido pelo serviço principal `moodle`.
