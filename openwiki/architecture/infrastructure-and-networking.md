---
type: architecture
title: Infraestrutura GCP, Adoção Seletiva e Cloud SQL MySQL 8.4
description: Arquitetura de provisionamento automatizado de VPC, GKE privado com drivers CSI, Cloud SQL MySQL 8.4, Memorystore Redis e controles de adoção seletiva em 0-infra.
tags: [gcp, gke, cloud-sql, mysql-8-4, redis, vpc, selective-adoption]
verified:
  - by: openwiki/0.5.1
    at: 2026-11-05T12:48:25.564Z
sources:
  - id: openwiki-source-75467caa28be1defc4942cd3
    resource: repo://0-infra/envs.sh
  - id: openwiki-source-c545e73e5570dc88f600931f
    resource: repo://0-infra/infra-creation.sh
generated: { by: "antigravity", at: "2026-11-05T12:48:25.564Z" }
---

# Infraestrutura GCP, Adoção Seletiva e Cloud SQL MySQL 8.4

O diretório `0-infra/` concentra toda a parametrização (`0-infra/envs.sh`), o provisionamento automatizado (`0-infra/infra-creation.sh`) e a reciclagem segura de ambiente (`0-infra/cleanup-moodle-install.sh`) da topologia do Moodle no Google Cloud Platform (GCP).

```mermaid
flowchart TD
    Envs["0-infra/envs.sh - Variáveis + validate_moodle_envs()"] --> Infra["0-infra/infra-creation.sh"]
    Infra --> VPC["VPC Custom + Subnet + Cloud NAT + IP Global moodle-ingress-ip"]
    Infra --> GKE["GKE Privado (Dataplane V2) - Addons: Filestore CSI + PD CSI"]
    Infra -->|CREATE_CLOUD_SQL=true| SQL["Cloud SQL MySQL 8.4 - VPC Peering + utf8mb4_unicode_ci"]
    Infra -->|CREATE_REDIS=true| Redis["Memorystore Redis 6.x - AUTH habilitado + allkeys-lru"]
    Infra -->|CREATE_REDIS_CLUSTER=true| MRC["Memorystore for Redis Cluster - Discovery Endpoint (MDL-59196)"]
    Infra -->|STORAGE_TYPE=filestore| FS["Cloud Filestore NFS - Tier e Capacidade Configuráveis"]
    Infra -->|STORAGE_TYPE=regional-pd| RPD["Regional Replicated PD - ZONE + REPLICA_ZONE"]
    Infra -->|CREATE_JUMPBOX=true| Jump["VM Jumpbox Debian 12 - OS Login + IAP"]
```

## Parametrização Central e Validação Pre-Flight (`0-infra/envs.sh`)

O arquivo `0-infra/envs.sh` centraliza os parâmetros de projeto, rede, banco de dados, cache e armazenamento:

- **Validação Pre-Flight (`validate_moodle_envs`)**: A função `validate_moodle_envs()` verifica se `PROJECT_NUMBER`, `PROJECT_ID` e `REGION` foram preenchidos e rejeita valores vazios ou que ainda contenham placeholders no formato `<YOUR-...>`, interrompendo a execução antes de disparar chamadas `gcloud` inválidas.
- **Execução Segura (`set -eo pipefail`)**: Os scripts `0-infra/infra-creation.sh` e `0-infra/cleanup-moodle-install.sh` utilizam `set -eo pipefail` (sem `-x` global durante operações sensíveis) e resolvem `SCRIPT_DIR` dinamicamente para carregar `envs.sh` independentemente do diretório de trabalho atual.

## Adoção Seletiva de Componentes de Infraestrutura

Para permitir que organizações reutilizem serviços gerenciados já existentes (como instâncias corporativas de Cloud SQL, Memorystore Redis ou topologias de storage pré-provisionadas), `0-infra/envs.sh` e `0-infra/infra-creation.sh` expõem flags independentes de adoção seletiva:

| Variável | Valor Padrão | Comportamento em `0-infra/infra-creation.sh` |
| :--- | :--- | :--- |
| `STORAGE_TYPE` | `filestore` | Define a modalidade de armazenamento (`filestore`, `regional-pd` ou `none`) e ajusta automaticamente os padrões de `CREATE_FILESTORE` e `CREATE_REGIONAL_PD`. |
| `CREATE_CLOUD_SQL` | `true` | Quando `true`, solicita interativamente `MYSQL_ROOT_PASSWORD` (com confirmação dupla se não definida), cria o range de VPC Peering `moodle-managed-range-mysql` e provisiona a instância Cloud SQL e o schema `$MYSQL_DB`. |
| `CREATE_REDIS` | `true` | Quando `true`, provisiona uma instância Memorystore for Redis (`redis_6_x`) com autenticação (`--enable-auth`) e política `allkeys-lru`. |
| `CREATE_REDIS_CLUSTER` | `false` | Quando `true`, provisiona um cluster Memorystore for Redis Cluster (`gcloud redis clusters create`) para implantações de larga escala com `RedisCluster` no Moodle 5.2+ (`Issue #23` / `MDL-59196`). |
| `CREATE_FILESTORE` | `true` (se `filestore`) | Quando `true`, habilita `file.googleapis.com`, aloca o peering `moodle-managed-range-filestore` e cria a instância Cloud Filestore com tier (`FILESTORE_TIER`) e capacidade (`FILESTORE_CAPACITY`) customizáveis. |
| `CREATE_REGIONAL_PD` | `true` (se `regional-pd`) | Quando `true`, cria um disco persistente regionalmente replicado (`gcloud compute disks create --region="$REGION" --replica-zones=...`) entre `$ZONE` e `$REPLICA_ZONE`. |
| `CREATE_JUMPBOX` | `true` | Quando `true`, cria a VM de suporte `vm-jumpbox-moodle` (Debian 12 Bookworm, sem IP externo, com `enable-oslogin=true`) para administração privada do cluster GKE. |

## Rede VPC, Cluster GKE Privado e Drivers CSI

O script `0-infra/infra-creation.sh` constrói uma VPC em modo customizado (`--mtu=1460`) com sub-rede primária (`SUBNET_RANGE`, padrão `10.10.0.0/24`) e dois ranges secundários dedicados ao GKE (`pod-range-gke-1` em `10.168.0.0/14` e `svc-range-gke-1` em `10.172.0.0/19`), além de Cloud Router e Cloud NAT para saída à internet dos nós privados.

O cluster GKE (`$GKE_NAME`) é provisionado com:
- **Dataplane V2 (`--enable-dataplane-v2`)**, nós privados (`--enable-private-nodes`), endpoint privado (`--enable-private-endpoint`) e `master-authorized-networks`.
- **Addons de Armazenamento e Ingress**: `HttpLoadBalancing`, `HorizontalPodAutoscaling`, `GcpFilestoreCsiDriver` e `GcePersistentDiskCsiDriver`, garantindo suporte nativo tanto a volumes NFS do Cloud Filestore quanto a discos `regional-pd` via `pd.csi.storage.gke.io`.

## Cloud SQL MySQL 8.4 para Moodle 5.0+

A partir do Moodle 5.0 (incluindo Moodle 5.1, 5.2.4 e 5.3), o verificador de ambiente do Moodle exige no mínimo **MySQL 8.4** (`MYSQL_8_4`).

- `0-infra/envs.sh` define `MYSQL_DATABASE_VERSION="${MYSQL_DATABASE_VERSION:-MYSQL_8_4}"` (permitindo sobrescrever para `MYSQL_8_0` caso o usuário deseje implantar Moodle 4.x).
- `0-infra/infra-creation.sh` provisiona a instância Cloud SQL com `--database-version="${MYSQL_DATABASE_VERSION:-MYSQL_8_4}"`, `--storage-type=SSD`, `--storage-auto-increase`, `--enable-bin-log` e cria o banco `$MYSQL_DB` com charset `utf8mb4` e collation `utf8mb4_unicode_ci`.
- Caso `MYSQL_ROOT_PASSWORD` não esteja exportada no ambiente e `CREATE_CLOUD_SQL=true`, `0-infra/infra-creation.sh` solicita a senha em modo silencioso (`read -rsp`) com validação de confirmação e desabilita `set -x` (`{ set +x; } 2>/dev/null`) antes da criação da instância para evitar vazamento de credenciais em logs.

## Limpeza e Reinicialização Segura (`0-infra/cleanup-moodle-install.sh`)

O script `0-infra/cleanup-moodle-install.sh` respeita as flags de adoção seletiva:
- Recria o banco `$MYSQL_DB` no Cloud SQL apenas quando `CREATE_CLOUD_SQL=true`.
- Quando `STORAGE_TYPE="filestore"`, valida que `DIR="$MOODLE_ROOT_IN_FILESTORE"` é não vazio e diferente de `/` antes de executar `sudo rm -rvf "${DIR:?}"`.
- Quando `STORAGE_TYPE="regional-pd"` e `RESET_REGIONAL_PD_ON_CLEANUP=true`, recria o disco regional `$PD_DISK_NAME` entre `$ZONE` e `$REPLICA_ZONE`.
