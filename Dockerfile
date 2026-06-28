FROM hub.froxlor.io/laravel/container:8.5-octane-minimal

LABEL maintainer="froxlor Team <team@froxlor.org>"
LABEL org.opencontainers.image.title="froxlor Container"
LABEL org.opencontainers.image.description="froxlor container image for Docker, Kubernetes, and other container platforms."
LABEL org.opencontainers.image.source=https://github.com/froxlor/container
LABEL org.opencontainers.image.licenses=LGPL-2.1-only

# Set working directory inside container
RUN git config --global --add safe.directory /var/www/html/froxlor
WORKDIR /var/www/html/froxlor

# Install openssl and stunnel for SSL termination
RUN apk add --no-cache openssl stunnel

# Copy scripts
COPY bin/ /opt/froxlor/bin/

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Expose ports
EXPOSE 8000
EXPOSE 8443

# Default command to run froxlor server
CMD ["composer", "run", "serve"]
