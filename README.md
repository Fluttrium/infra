# fluttrium-infra

Инфраструктура платформы: приватный реестр пакетов, реверс-прокси с TLS, первоначальная
настройка сервера. Клонируется на сервер — дальше всё запускается готовыми файлами,
без копипаста.

## Состав
- `server/cloud-init.yaml` — автонастройка свежего VPS (пользователь, SSH-ключи, Docker, ufw).
- `server/docker-daemon.json` — зеркала Docker Hub (РФ).
- `server/Caddyfile` + `docker-compose.caddy.yml` — авто-HTTPS на `*.fluttrium.store`.
- `registry/` — Verdaccio: приватный npm-реестр + зеркало публичного npm.

## Развёртывание (на сервере)
```bash
git clone https://github.com/Fluttrium/infra.git
cd infra

# 1) зеркала Docker Hub (РФ)
sudo cp server/docker-daemon.json /etc/docker/daemon.json && sudo systemctl restart docker

# 2) приватный реестр
cd registry && docker compose up -d && cd ..

# 3) авто-HTTPS (нужны DNS-записи npm/api → IP сервера и порты 80/443)
cd server && docker compose -f docker-compose.caddy.yml up -d
```

## DNS (у регистратора домена)
```
A   npm   <IP-сервера>
A   api   <IP-сервера>
```

Секретов в репо нет (токены — через env `${NPM_TOKEN}`).
