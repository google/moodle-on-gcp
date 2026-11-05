---
type: architecture
title: "Modalidades de Storage: Filestore vs. Regional Replicated Persistent Disk"
description: Arquitetura comparativa, dimensionamento configurável de PV/PVC e provisionamento de Cloud Filestore (RWX) e Regional Replicated Persistent Disks (regional-pd) no GKE.
tags: [storage, filestore, regional-pd, csi, persistent-volume, gke]
verified:
  - by: openwiki/0.5.1
    at: 2026-11-05T11:15:21.468Z
sources:
  - id: openwiki-source-75467caa28be1defc4942cd3
    resource: repo://0-infra/envs.sh
  - id: openwiki-source-c545e73e5570dc88f600931f
    resource: repo://0-infra/infra-creation.sh
  - id: openwiki-source-fe652ec2e041ec3ba0455e70
    resource: repo://1-pv/pv-regional-pd.yaml
  - id: openwiki-source-74a56aabcbac6ab962ebaada
    resource: repo://1-pv/storageclass-regional-pd.yaml
  - id: openwiki-source-7942098d6651cd565a0b8602
    resource: repo://3-pvc/pvc-regional-pd.yaml
  - id: openwiki-source-b23bb47d51c7c03a516ab733
    resource: repo://5a-deployment-no-helm/create-config-files.sh
generated: { by: "antigravity", at: "2026-11-05T11:15:21.468Z" }
---

# Modalidades de Storage: Filestore vs. Regional Replicated Persistent Disk

O Moodle armazena o diretório de dados (`$CFG->dataroot`) e, na arquitetura padrão deste repositório, o código-fonte compartilhado (`/$MOODLE_ROOT_PATH_NO_SLASH/moodle`) e os diretórios de configuração runtime (`/etc/nginx`, `/etc/php83`, `/etc/nginx-uploads`, `/etc/php83-uploads`) em um volume persistente montado pelos pods no GKE.

Por meio da variável `STORAGE_TYPE` em `0-infra/envs.sh`, o repositório suporta três modalidades de adoção de armazenamento:

1. **`STORAGE_TYPE="filestore"` (Padrão)**: Cloud Filestore gerenciado via NFS (`ReadWriteMany`).
2. **`STORAGE_TYPE="regional-pd"`**: Disco Persistente Regionalmente Replicado (`Regional Replicated Persistent Disk`) entre duas zonas (`$ZONE` e `$REPLICA_ZONE`) via driver CSI `pd.csi.storage.gke.io`.
3. **`STORAGE_TYPE="none"`**: Pula o provisionamento de storage em `0-infra/infra-creation.sh` para permitir a integração de volumes externos pré-existentes.

<!-- openwiki: mermaid parse failed and this diagram was converted to a text fence so it does not break rendering. Fix the diagram source and restore the mermaid fence. Parser error: Heuristic: an unescaped angle bracket inside a label breaks rendering; rephrase the label. -->
```text
flowchart LR
    Env["0-infra/envs.sh<br/>STORAGE_TYPE"] -->|filestore| FS["Cloud Filestore<br/>FILESTORE_TIER + FILESTORE_CAPACITY"]
    Env -->|regional-pd| RPD["Compute Engine Regional PD<br/>ZONE + REPLICA_ZONE + PD_DISK_SIZE"]
    FS --> PV_FS["1-pv/pv-filestore.yaml<br/>ReadWriteMany (NFS)"]
    PV_FS --> PVC_FS["3-pvc/pvc-filestore.yaml<br/>pvc-filestore"]
    RPD --> PV_RPD["1-pv/pv-regional-pd.yaml<br/>pd.csi.storage.gke.io"]
    RPD --> SC_RPD["1-pv/storageclass-regional-pd.yaml<br/>replication-type: regional-pd"]
    PV_RPD --> PVC_RPD["3-pvc/pvc-regional-pd.yaml<br/>pvc-regional-pd"]
```

## Comparativo entre Cloud Filestore e Regional Replicated PD

| Característica | Cloud Filestore (`STORAGE_TYPE="filestore"`) | Regional Replicated Persistent Disk (`STORAGE_TYPE="regional-pd"`) |
| :--- | :--- | :--- |
| **Protocolo / Driver** | NFSv3 (`nfs` no `PersistentVolume`) | Bloco via CSI (`pd.csi.storage.gke.io`, `fsType: ext4`) |
| **Modo de Acesso (`accessModes`)** | `ReadWriteMany` (`RWX`) simultâneo entre múltiplos nós GKE | `ReadWriteOnce` (`RWO`, pods no mesmo nó com failover automático entre zonas) ou `ReadOnlyMany` (`ROX`) |
| **Replicação / Alta Disponibilidade** | Zonal (`BASIC_HDD`, `BASIC_SSD`, `ZONAL`) ou Regional (`REGIONAL`, `ENTERPRISE`) | Replicação síncrona nativa de blocos entre duas zonas (`$ZONE` e `$REPLICA_ZONE`) |
| **Capacidade Mínima** | `1TB` (`BASIC_HDD`, `ZONAL`, `REGIONAL`) ou `2.5TB` (`BASIC_SSD`) | A partir de `10Gi`–`200Gi` (`PD_DISK_SIZE="200Gi"` por padrão) |
| **Custo Inicial** | Mais elevado devido à capacidade mínima de 1 TiB / 2.5 TiB | Significativamente menor para ambientes de pequeno/médio porte ou homologação HA |

## Parametrização de Tamanhos e Capacidades (`0-infra/envs.sh` e `create-config-files.sh`)

Todas as variáveis de capacidade e tipo de armazenamento são definidas em `0-infra/envs.sh` e propagadas automaticamente para os manifestos Kubernetes por `5a-deployment-no-helm/create-config-files.sh`:

- **Cloud Filestore**:
  - `FILESTORE_TIER`: `BASIC_SSD` (padrão), `BASIC_HDD`, `ZONAL`, `REGIONAL` ou `ENTERPRISE`. Em `0-infra/infra-creation.sh`, tiers `REGIONAL` e `ENTERPRISE` utilizam `--location="$REGION"`, enquanto tiers zonais utilizam `--zone="$ZONE"`.
  - `FILESTORE_CAPACITY`: Capacidade da instância Filestore (padrão `2.5TB`).
  - `FILESTORE_SHARE_NAME`: Nome do compartilhamento NFS (padrão `moodleshare`).
- **Regional Replicated Persistent Disk (`regional-pd`)**:
  - `REPLICA_ZONE`: Segunda zona na mesma região (`$REGION-b`) para replicação síncrona junto à zona primária `$ZONE` (`$REGION-a`).
  - `PD_DISK_NAME`: Nome do disco regional no Compute Engine.
  - `PD_DISK_TYPE`: `pd-balanced` (padrão), `pd-ssd`, `pd-standard` ou `hyperdisk-balanced-high-availability`.
  - `PD_DISK_SIZE`: Tamanho do disco regional e do PV/PVC correspondente (padrão `200Gi`).
  - `PD_ACCESS_MODE`: Modo de acesso do volume (padrão `ReadWriteOnce`).
- **Tamanhos de PV e PVC (`PV_STORAGE_SIZE`, `PVC_STORAGE_SIZE`, `PVC_LIMIT_STORAGE_SIZE`)**:
  - Para `STORAGE_TYPE="filestore"`, os padrões são `PV_STORAGE_SIZE="2.5Ti"`, `PVC_STORAGE_SIZE="300Gi"`, `PVC_LIMIT_STORAGE_SIZE="500Gi"` e `PVC_CLAIM_NAME="pvc-filestore"`.
  - Para `STORAGE_TYPE="regional-pd"`, os padrões ajustam-se automaticamente para `200Gi` e `PVC_CLAIM_NAME="pvc-regional-pd"`.

## Provisionamento Estático vs. Dinâmico de Regional Replicated PD

O repositório oferece suporte tanto ao provisionamento estático quanto dinâmico de discos regionais replicados no GKE:

1. **Provisionamento Estático (`1-pv/pv-regional-pd.yaml` + `3-pvc/pvc-regional-pd.yaml`)**:
   - `0-infra/infra-creation.sh` cria o disco regional com `--region="$REGION"` e `--replica-zones="projects/$PROJECT_ID/zones/$ZONE,projects/$PROJECT_ID/zones/$REPLICA_ZONE"`.
   - `1-pv/pv-regional-pd.yaml` referencia `volumeHandle: projects/$PROJECT_ID/regions/$REGION/disks/$PD_DISK_NAME` via `driver: pd.csi.storage.gke.io` e restringe o agendamento aos nós das duas zonas via `nodeAffinity` (`topology.gke.io/zone in [$ZONE, $REPLICA_ZONE]`).
2. **Provisionamento Dinâmico (`1-pv/storageclass-regional-pd.yaml`)**:
   - Define uma `StorageClass` (`moodle-regional-pd`) com `provisioner: pd.csi.storage.gke.io`, `replication-type: regional-pd`, `type: $PD_DISK_TYPE`, `zones: $ZONE, $REPLICA_ZONE`, `allowVolumeExpansion: true` e `volumeBindingMode: WaitForFirstConsumer`.
