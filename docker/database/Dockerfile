# Pro-Mata PostgreSQL Custom Image
FROM postgres:15-alpine

# Labels para metadados
LABEL org.label-schema.name="pro-mata-database" \
      org.label-schema.description="PostgreSQL customizado para Pro-Mata" \
      org.label-schema.vendor="AGES PUCRS" \
      org.label-schema.version="15-alpine-promata"

# Install additional packages and extensions
RUN apk add --no-cache \
    postgresql-contrib \
    postgresql-client \
    curl \
    bash \
    tzdata \
    # Tools for backup and monitoring
    gzip \
    # Network utilities
    netcat-openbsd \
    # Process monitoring
    procps

# Set timezone to Brazil
RUN cp /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
RUN echo "America/Sao_Paulo" > /etc/timezone

# Create directories for custom configurations
RUN mkdir -p /etc/postgresql/conf.d \
             /var/lib/postgresql/backups \
             /var/lib/postgresql/scripts

# Copy custom PostgreSQL configurations
COPY configs/postgresql.conf /etc/postgresql/postgresql.conf
COPY configs/pg_hba.conf /etc/postgresql/pg_hba.conf
COPY configs/recovery.conf /etc/postgresql/recovery.conf.template

# Copy initialization scripts
COPY scripts/init/ /docker-entrypoint-initdb.d/
COPY scripts/replication/ /usr/local/bin/
COPY scripts/backup/ /usr/local/bin/

# Copy custom entrypoint
COPY entrypoint.sh /usr/local/bin/docker-entrypoint-custom.sh

# Set permissions
RUN chmod +x /usr/local/bin/*.sh
RUN chmod +x /docker-entrypoint-initdb.d/*.sh
RUN chmod 644 /etc/postgresql/*.conf
RUN chown -R postgres:postgres /var/lib/postgresql/backups
RUN chown -R postgres:postgres /var/lib/postgresql/scripts

# Set environment variables for Pro-Mata
ENV POSTGRES_INITDB_ARGS="--encoding=UTF-8 --lc-collate=pt_BR.UTF-8 --lc-ctype=pt_BR.UTF-8"
ENV POSTGRES_HOST_AUTH_METHOD=md5
ENV TZ=America/Sao_Paulo
ENV PGTZ=America/Sao_Paulo

# Health check customizado para Pro-Mata
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD pg_isready -U $POSTGRES_USER -d $POSTGRES_DB -h localhost || exit 1

# Expose standard PostgreSQL port
EXPOSE 5432

# Use custom entrypoint
ENTRYPOINT ["docker-entrypoint-custom.sh"]
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]