FROM alpine:3.20

RUN apk add --no-cache git-daemon \
  && git config --system --add safe.directory '*'

EXPOSE 9418

ENTRYPOINT ["git", "daemon", "--verbose", "--export-all", "--base-path=/git", "--reuseaddr", "--listen=0.0.0.0", "/git"]
