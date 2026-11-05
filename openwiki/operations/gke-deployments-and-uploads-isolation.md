---
type: operations
title: Deployments GKE, Isolamento de Pods de Upload e HPA
description: Arquitetura de Deployments Kubernetes para o Moodle 5.2.4, isolamento de subPaths e recursos para pods dedicados a uploads pesados, geração via create-config-files.sh e políticas de HPA.
tags: [gke, kubernetes, deployments, uploads, hpa, configmap, envsubst]
verified:
  - by: openwiki/0.5.1
    at: 2026-11-05T11:15:21.468Z
sources:
  - id: openwiki-source-b23bb47d51c7c03a516ab733
    resource: repo://5a-deployment-no-helm/create-config-files.sh
  - id: openwiki-source-53006dbc93bd922d7c60cef7
    resource: repo://5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml
  - id: openwiki-source-a72c418fe1c6ecb6d937d386
    resource: repo://5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml
  - id: openwiki-source-93141f93130a498670374709
    resource: repo://5a-deployment-no-helm/moodle-deployment-nginx.yaml
  - id: openwiki-source-14c80d2e5990cedcc69cd8f7
    resource: repo://9-hpa/moodle-hpa.yaml
  - id: openwiki-source-d5cb738866bc0951047c9d59
    resource: repo://9-hpa/moodle-uploads-hpa.yaml
generated: { by: "antigravity", at: "2026-11-05T11:15:21.468Z" }
---

# Deployments GKE, Isolamento de Pods de Upload e HPA

O diretório `5a-deployment-no-helm/` implementa uma arquitetura de **dois tiers de aplicação no GKE**:
1. **Tier Web Principal (`moodle-deployment` + `moodle-configmap` + `moodle`)**: Dimensionado para navegação interativa rápida, cache no Cloud CDN e escalonamento horizontal de 3 a 9 réplicas (`9-hpa/moodle-hpa.yaml`).
2. **Tier Dedicado de Uploads (`moodle-deployment-uploads` + `moodle-configmap-uploads` + `moodle-service-uploads`)**: Dimensionado para uploads pesados de arquivos (até `512M` por requisição, timeout de `3600s` e limite de `2Gi` de RAM por pod), escalando de 1 a 5 réplicas (`9-hpa/moodle-uploads-hpa.yaml`).

<!-- openwiki: mermaid parse failed and this diagram was converted to a text fence so it does not break rendering. Fix the diagram source and restore the mermaid fence. Parser error: Heuristic: an unescaped angle bracket inside a label breaks rendering; rephrase the label. -->
```text
flowchart TD
    Script["5a-deployment-no-helm/create-config-files.sh"] --> CM1["moodle-configmap-nginx.yaml"]
    Script --> CM2["moodle-configmap-nginx-uploads.yaml<br/>CLIENT_MAX_BODY_SIZE=512M<br/>PHP_MEMORY_LIMIT=512M"]
    Script --> Dep1["moodle-deployment-nginx.yaml<br/>subPath: etc/nginx & etc/php83"]
    Script --> Dep2["moodle-deployment-nginx-uploads.yaml<br/>subPath: etc/nginx-uploads & etc/php83-uploads"]
    Dep1 --> HPA1["9-hpa/moodle-hpa.yaml (3..9 pods)"]
    Dep2 --> HPA2["9-hpa/moodle-uploads-hpa.yaml (1..5 pods)"]
```

## 1. Renderização Automatizada de Manifestos (`create-config-files.sh`)

O script `5a-deployment-no-helm/create-config-files.sh` carrega `0-infra/envs.sh` e executa `envsubst` sobre os templates localizados em `5a-deployment-no-helm/deployment-templates/`:

- Determina automaticamente `PVC_CLAIM_NAME` (`pvc-regional-pd` quando `STORAGE_TYPE="regional-pd"`, ou `pvc-filestore` caso contrário).
- Renderiza `moodle-configmap-nginx.yaml`, `moodle-configmap-nginx-uploads.yaml`, `moodle-deployment-nginx.yaml` e `moodle-deployment-nginx-uploads.yaml` substituindo `$MOODLE_ROOT_PATH_NO_SLASH` e `$PVC_CLAIM_NAME`.
- Renderiza os manifestos de armazenamento (`1-pv/pv-filestore.yaml`, `3-pvc/pvc-filestore.yaml`, `1-pv/storageclass-regional-pd.yaml`, `1-pv/pv-regional-pd.yaml`, `3-pvc/pvc-regional-pd.yaml`) com as capacidades configuradas em `0-infra/envs.sh`.
- Caso executado em terminal interativo (ou quando `ENABLE_SMTP="true"`), solicita opcionalmente `SMTP_PASSWORD` com confirmação dupla e injeta o valor escapado em `moodle-configmap-nginx.yaml` e `moodle-configmap-nginx-uploads.yaml`.

## 2. Isolamento de Configuração e Recursos nos Pods de Upload

No deployment principal (`moodle-deployment`), os diretórios `/etc/nginx` e `/etc/php83` são montados no volume compartilhado usando `subPath: $MOODLE_ROOT_PATH_NO_SLASH/etc/nginx` e `subPath: $MOODLE_ROOT_PATH_NO_SLASH/etc/php83`.

Se os pods dedicados de upload compartilhassem o mesmo `subPath` de configuração, as substituições via `sed -i` executadas por `setup_moodle.sh` nos pods de upload sobrescreveriam o `php.ini` e o `nginx.conf` dos pods web principais no volume compartilhado. Para impedir essa colisão:

- `5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml` monta `/etc/nginx` em `subPath: $MOODLE_ROOT_PATH_NO_SLASH/etc/nginx-uploads` e `/etc/php83` em `subPath: $MOODLE_ROOT_PATH_NO_SLASH/etc/php83-uploads`, enquanto continua compartilhando o mesmo código-fonte (`subPath: $MOODLE_ROOT_PATH_NO_SLASH/moodle`) e o mesmo diretório de dados (`subPath: $MOODLE_ROOT_PATH_NO_SLASH/moodledata`).
- `5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml` define limites dedicados para uploads grandes:
  - `CLIENT_MAX_BODY_SIZE: "512M"`
  - `UPLOAD_MAX_FILESIZE: "512M"`
  - `POST_MAX_SIZE: "512M"`
  - `PHP_MAX_EXECUTION_TIME: "3600"`
  - `PHP_MAX_INPUT_TIME: "3600"`
  - `PHP_MEMORY_LIMIT: "512M"`
- Os pods de `moodle-deployment-uploads` possuem `limits.cpu: 500m` e `limits.memory: 2Gi` (`requests: 250m / 1Gi`), evitando que uploads simultâneos causem `OOMKilled` ou esgotem workers PHP-FPM do tráfego geral de alunos.

## 3. Escalonamento Horizontal Independente (`9-hpa/`)

- **`9-hpa/moodle-hpa.yaml`**: Escala `moodle-deployment` entre `minReplicas: 3` e `maxReplicas: 9` com metas de utilização média de `75%` de CPU e `80%` de memória.
- **`9-hpa/moodle-uploads-hpa.yaml`**: Escala `moodle-deployment-uploads` de forma independente entre `minReplicas: 1` e `maxReplicas: 5` com metas de `75%` de CPU e `80%` de memória.
