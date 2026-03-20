FROM postgres:15-alpine

RUN apk add --no-cache curl bash jq

COPY init.sh /init.sh
RUN chmod +x /init.sh

ENTRYPOINT ["/init.sh"]
