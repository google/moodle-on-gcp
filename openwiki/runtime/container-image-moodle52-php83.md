---
type: runtime
title: Imagem Container NGINX + PHP 8.3, GNU libiconv e Bootstrap do Moodle 5.2+
description: Construção multi-stage em Alpine 3.21 + PHP 8.3, compilação de preloadable_libiconv.so, suporte ao diretório /public do Moodle 5.1+, Composer e Moosh 1.51.
tags: [docker, alpine, php83, libiconv, moodle-5-2, moosh, composer]
verified:
  - by: openwiki/0.5.1
    at: 2026-11-05T11:15:21.468Z
sources:
  - id: openwiki-source-9668b922e15526bcb075e159
    resource: repo://4-moodle-image-builder/base/opt/entrypoint.sh
  - id: openwiki-source-9e3267e0548e0d3f7ee9310d
    resource: repo://4-moodle-image-builder/base/opt/setup_moodle.sh
  - id: openwiki-source-4bd036642052c68bf1eeafa3
    resource: repo://4-moodle-image-builder/config.php.template
  - id: openwiki-source-34c6a932713f38d6c8e1c2df
    resource: repo://4-moodle-image-builder/Dockerfile.nginx
  - id: openwiki-source-264fd3f40ce4ca69414ec2b9
    resource: repo://4-moodle-image-builder/scripts/build-gnu-libiconv.sh
generated: { by: "antigravity", at: "2026-11-05T11:15:21.468Z" }
---

# Imagem Container NGINX + PHP 8.3, GNU libiconv e Bootstrap do Moodle 5.2+

O diretório `4-moodle-image-builder/` constrói a imagem base do Moodle no GKE sobre **Alpine Linux 3.21**, **NGINX 1.26** e **PHP 8.3 (`8.3.36`)**, resolvendo todos os requisitos de runtime introduzidos no Moodle 5.0, 5.1 e 5.2.4.

<!-- openwiki: mermaid parse failed and this diagram was converted to a text fence so it does not break rendering. Fix the diagram source and restore the mermaid fence. Parser error: Heuristic: an unescaped angle bracket inside a label breaks rendering; rephrase the label. -->
```text
flowchart TD
    S1["Stage 1: libiconv-builder (alpine:3.21)<br/>scripts/build-gnu-libiconv.sh<br/>Gera /usr/lib/preloadable_libiconv.so"] --> S2["Stage 2: Runtime (alpine:3.21)<br/>PHP 8.3 + NGINX + Composer + ClamAV"]
    S2 --> Test["Verificação Build-Time:<br/>LD_PRELOAD=/usr/lib/preloadable_libiconv.so<br/>iconv('UTF-8', 'ASCII//TRANSLIT', 'Olá')"]
    Test --> Entry["/opt/entrypoint.sh"]
    Entry --> Setup["/opt/setup_moodle.sh<br/>1. envsubst + sed overrides<br/>2. Download Moodle 5.2.4 + composer install<br/>3. CLI install.php + install_database.php<br/>4. Auto-ajuste NGINX root -> /public<br/>5. Moosh 1.51 + plugins"]
    Entry --> Daemons["crond + /usr/sbin/php-fpm83 + nginx"]
```

## 1. Compilação Multi-Stage do `preloadable_libiconv.so` (MDL-80440)

A biblioteca padrão `musl` do Alpine Linux não suporta o modificador `//TRANSLIT` na função `iconv()`, exigido pelo Moodle (`MDL-80440`). Em vez de instalar pacotes legados de repositórios `alpine/v3.13` (que quebram com toolchains modernos), `4-moodle-image-builder/Dockerfile.nginx` utiliza um build multi-stage:

1. **Stage 1 (`libiconv-builder`)**: Executa `4-moodle-image-builder/scripts/build-gnu-libiconv.sh`, que compila uma biblioteca compartilhada `/usr/lib/preloadable_libiconv.so` exportando os símbolos POSIX `iconv_open`, `iconv` e `iconv_close` vinculados à `gnu-libiconv-dev` atual do Alpine 3.21 (ou compilando o código-fonte oficial `libiconv-1.18` quando invocado com `--from-source`).
2. **Stage 2 (Runtime)**: Copia `/usr/lib/preloadable_libiconv.so`, instala `gnu-libiconv-libs` e `icu-data-full`, define `ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so` e valida a transliteração em tempo de build (`php -r 'if (iconv("UTF-8", "ASCII//TRANSLIT", "Olá") === false) exit(1);'`).

## 2. PHP 8.3 e Verificação Dinâmica do Composer

O `Dockerfile.nginx` instala todos os pacotes `php83-*` requeridos pelo Moodle 5.2.4 (`php83-fpm`, `php83-opcache`, `php83-mysqli`, `php83-pdo_mysql`, `php83-intl`, `php83-soap`, `php83-sodium`, `php83-exif`, `php83-zip`, `php83-gd`, `php83-pecl-redis`, `php83-pecl-igbinary`, `php83-pecl-apcu`, `php83-pecl-zstd`), cria o symlink `/usr/bin/php -> /usr/bin/php83` e instala o Composer verificando dinamicamente o hash SHA-384 contra `https://composer.github.io/installer.sig`.

O `4-moodle-image-builder/base/opt/entrypoint.sh` executa `/opt/setup_moodle.sh` e inicia `/usr/sbin/crond`, `/usr/sbin/php-fpm83` e `/usr/sbin/nginx -g "daemon off;"`.

## 3. Bootstrap do Moodle 5.2.4, Dependências Composer e Webroot `/public` (`setup_moodle.sh`)

O script `4-moodle-image-builder/base/opt/setup_moodle.sh` orquestra a inicialização idempotente do Moodle:

1. **Templates e Sobrescritas Dinâmicas (`envsubst` + `sed -i`)**:
   - Renderiza `/etc/nginx/nginx.conf` e `/etc/php83/php.ini` via `envsubst` e aplica imediatamente as variáveis de ambiente opcionais (`PHP_MEMORY_LIMIT`, `PHP_UPLOAD_MAX_FILESIZE`/`UPLOAD_MAX_FILESIZE`, `PHP_POST_MAX_SIZE`/`POST_MAX_SIZE`, `PHP_MAX_EXECUTION_TIME`, `PHP_MAX_INPUT_TIME`, `NGINX_CLIENT_MAX_BODY_SIZE`/`CLIENT_MAX_BODY_SIZE`).
2. **Instalação das Dependências Composer do Moodle 5.1+**:
   - A partir do Moodle 5.1, o diretório `vendor/` não é mais versionado no tarball do GitHub. `setup_moodle.sh` detecta `composer.json` e executa `sudo -u www composer install --no-dev --classmap-authoritative --no-interaction --working-dir="$MOODLE_PATH"` tanto na instalação inicial quanto em atualizações (`.moodle-autoupgrade`).
3. **Detecção Automática do Diretório `/public` (`MDL-83424`)**:
   - No Moodle 5.1+, todos os pontos de entrada web foram movidos para `$MOODLE_PATH/public`. `setup_moodle.sh` verifica `if [ -d "$MOODLE_PATH/public" ]` e atualiza automaticamente a diretiva `root` em `/etc/nginx/nginx.conf` para `root ${MOODLE_ROOT_PATH}/moodle/public;`, mantendo retrocompatibilidade transparente com Moodle 4.x e 5.0.
4. **Moosh 1.51 (`master`) e Plugins (`report_benchmark`, `tool_opcache`, `local_redislock`)**:
   - Utiliza o branch `master` do Moosh (v1.51+, que suporta a estrutura `/public` do Moodle 5.1/5.2) para instalar `report_benchmark`, `tool_opcache` e, quando `REDIS_LOCK_HOST_AND_PORT` está definido, `local_redislock`.
   - Em `4-moodle-image-builder/config.php.template`, a configuração de lock no Redis verifica `class_exists('\\local_redislock\\lock\\redis_lock_factory')` antes de ativar `$CFG->lock_factory`, prevenindo falhas fatais durante o bootstrap antes da instalação do plugin pelo Moosh.
