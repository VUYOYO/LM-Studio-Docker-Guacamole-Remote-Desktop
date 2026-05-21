FROM alpine:3.20

COPY wait-init.sh /usr/local/bin/wait-init.sh
RUN chmod +x /usr/local/bin/wait-init.sh

ENTRYPOINT ["/usr/local/bin/wait-init.sh"]
