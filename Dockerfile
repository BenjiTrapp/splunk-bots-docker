ARG BOTS_VERSION
FROM splunk/splunk:8.2.3

ARG BOTS_VERSION
ARG SPLUNK_APPS_URL
ENV SPLUNK_START_ARGS=--accept-license
ENV SPLUNK_APPS_URL=${SPLUNK_APPS_URL}

COPY apps/session_config /opt/splunk/etc/apps/session_config/
COPY apps/botsv${BOTS_VERSION}/ /tmp/apps/
