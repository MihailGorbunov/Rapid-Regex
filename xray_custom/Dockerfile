FROM alpine:latest AS configure

WORKDIR /configure
# Устанавливаем зависимости
RUN apk add --no-cache bash curl openssl unzip bind-tools python3 py3-pip jq

# Копируем основной скрипт
COPY ["scripts/xray_prepare.sh", "."]
RUN chmod +x ./xray_prepare.sh

# Копируем скрипт проверки авторизации
COPY ["scripts/post_register.sh", "."]
RUN chmod +x ./post_register.sh

COPY ["scripts/launcher.sh", "."]
RUN chmod +x ./launcher.sh

# Копируем другие файлы
COPY ["xray", "."]
RUN chmod +x ./xray

COPY ["config.json", "."]
COPY ["connstring.txt", "."]
COPY ["client.json", "."]

# Создаём рабочие директории
RUN mkdir -p output

FROM teddysun/xray:latest

# Устанавливаем зависимости
RUN apk add --no-cache bash curl openssl unzip bind-tools python3 py3-pip jq

WORKDIR /configure

COPY --from=configure /configure /configure

ENTRYPOINT ["./launcher.sh"]
