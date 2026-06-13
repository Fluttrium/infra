# Автонастройка VPS при первой загрузке (cloud-init)

Скрипт, который провайдер выполняет один раз при создании сервера. Поднимает бокс
сразу настроенным: пользователь `deploy`, вход только по SSH-ключу, фаервол, Docker,
swap, авто-обновления безопасности.

Два варианта (выбери под формат поля у провайдера):

- **`cloud-init.yaml`** — `#cloud-config` (рекомендуется). Для полей «user-data» / «cloud-init».
- **`bootstrap.sh`** — обычный bash. Для полей, принимающих шелл-скрипт.

## Перед загрузкой — обязательно

1. Создай ключ на маке (если ещё нет):
   ```bash
   ssh-keygen -t ed25519 -C "roman@fluttrium" -f ~/.ssh/fluttrium_vps
   ```
2. Скопируй **публичный** ключ:
   ```bash
   cat ~/.ssh/fluttrium_vps.pub
   ```
3. Вставь его в скрипт **вместо плейсхолдера**:
   - в `cloud-init.yaml` — строка под `ssh_authorized_keys:`
   - в `bootstrap.sh` — переменная `PUBKEY`

   ⚠️ Если вставишь неверный ключ — запрёшь себя. Запасной вход — **веб-консоль/VNC**
   в панели провайдера (там можно зайти и поправить).

## Как загрузить у провайдера

- **Timeweb Cloud / Selectel / Yandex Cloud:** при создании сервера найди поле
  **«Cloud-init» / «user-data» / «Скрипт первоначальной настройки»** и вставь туда
  содержимое `cloud-init.yaml` (или `bootstrap.sh`). ОС бери **Ubuntu 24.04** или
  **Debian 12**. Точная подпись поля — в доках провайдера (ты её и упоминал).

## Что делает

- Пользователь `deploy` с sudo (работаешь под ним, не под root).
- Кладёт твой публичный ключ, отключает вход под root и по паролю (только ключ).
- `ufw`: наружу только 22/80/443. Порты 3000 (API), 5432 (БД), 4873 (реестр) — НЕ
  публикуются, доступ к ним только через SSH-туннель или reverse-proxy.
- Ставит Docker + compose-плагин, добавляет `deploy` в группу docker.
- `fail2ban` (защита SSH от перебора), `unattended-upgrades` (авто security-патчи).
- swap 2 ГБ.

## После загрузки — проверка

```bash
ssh deploy@<IP>           # должен пустить по ключу, без пароля
docker --version          # Docker есть
docker compose version    # compose-плагин есть
sudo ufw status           # 22/80/443 allow
```

Логи cloud-init на сервере (если что-то пошло не так):
```bash
sudo cat /var/log/cloud-init-output.log
```

## РФ-нюансы (важно)

- **Docker ставим из репозиториев дистрибутива** (`docker.io` + `docker-compose-v2`), а
  НЕ через `get.docker.com` — его CDN из РФ часто недоступен (SSL timeout). Поэтому
  рекомендуется **Ubuntu 24.04** (там есть `docker-compose-v2`).
- **Docker Hub** (откуда тянутся образы `postgres`, `node`, `oven/bun`, `verdaccio`) из РФ
  **заблокирован** (`TLS handshake timeout`). Нужно зеркало — готовый конфиг в
  `infra/server/docker-daemon.json`, скопируй его в `/etc/docker/daemon.json` и
  `sudo systemctl restart docker`. Зеркала (на 2026): `dockerhub.timeweb.cloud` (если ты
  на Timeweb — самое быстрое), `huecker.io`, `dh-mirror.gitverse.ru`. Проверь актуальность
  у своего провайдера — список меняется.
- **Альтернатива:** собирай образ не на VPS, а у себя/в CI и пушь готовый в свой реестр —
  тогда VPS не ходит на Docker Hub вообще.

## Дальше

Сервер готов принимать деплой. Следующий шаг — выкатить на него образ
(`docker compose up -d` из репо-инстанса) + Caddy для авто-TLS перед API. Это уже
прод-обвязка деплой-юнита (Фаза B).
