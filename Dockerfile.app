FROM wechatopenai/weknora-app:v0.9.0

# Upstream image unchanged; the wrapper validates the secrets, binds on both address families
# and then runs upstream's own entrypoint (chown of the upload volume, drop to appuser).
COPY --chmod=755 app-entrypoint.sh /app/railway-entrypoint.sh

ENV GIN_MODE=release \
    TZ=UTC \
    PORT=8080 \
    DB_DRIVER=postgres \
    DB_PORT=5432 \
    RETRIEVE_DRIVER=postgres \
    STREAM_MANAGER_TYPE=redis \
    REDIS_DB=0 \
    STORAGE_TYPE=local \
    LOCAL_STORAGE_BASE_DIR=/data/files \
    DOCREADER_TRANSPORT=grpc \
    AUTO_MIGRATE=true \
    AUTO_RECOVER_DIRTY=true \
    OLLAMA_OPTIONAL=true \
    WEKNORA_SANDBOX_DOCKER_ENABLED=false \
    WEKNORA_LANGUAGE=en-US

EXPOSE 8080
ENTRYPOINT ["/app/railway-entrypoint.sh"]
CMD ["./WeKnora"]
