# SPDX-FileCopyrightText: 2026 the froxlor Team (see AUTHORS)
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LicenseRef-froxlor-Extension-Package-Exception
#
# This file is part of the froxlor project.
#
# This library is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version, with the froxlor
# Extension Package Exception (see LICENSE-EXCEPTION).
#
# This library is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library. If not, see
# <https://www.gnu.org/licenses/>.

FROM hub.froxlor.io/laravel/container:8.5-octane-minimal

LABEL maintainer="froxlor Team <team@froxlor.org>"
LABEL org.opencontainers.image.title="froxlor Container"
LABEL org.opencontainers.image.description="froxlor container image for Docker, Kubernetes, and other container platforms."
LABEL org.opencontainers.image.source=https://github.com/froxlor/container
LABEL org.opencontainers.image.licenses="LGPL-3.0-or-later WITH LicenseRef-froxlor-Extension-Package-Exception"

# Set working directory inside container
RUN git config --global --add safe.directory /var/www/html/froxlor
WORKDIR /var/www/html/froxlor

# Install openssl and stunnel for SSL termination, supervisor for the production processes
RUN apk add --no-cache openssl stunnel supervisor

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

# Production: web server, queue workers and scheduler under supervisord (bin/run.sh);
# development runs "composer run serve" instead (compose.yml)
CMD ["/opt/froxlor/bin/run.sh"]
