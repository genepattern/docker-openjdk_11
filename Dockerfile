# copyright 2017-2019 Regents of the University of California and the Broad Institute. All rights reserved.
FROM adoptopenjdk/openjdk11:alpine-jre

# Default to UTF-8 file.encoding
ENV LANG C.UTF-8

COPY common/container_scripts/*.sh /usr/local/bin/

RUN apk -v --update add \
        bash \
        python \
        py-pip \
        groff \
        less \
        mailcap \
        freetype-dev \
        fontconfig \
        ttf-dejavu \
        && \
    pip install --upgrade awscli==1.14.5 s3cmd==2.0.1 python-magic && \
    apk -v --purge del py-pip && \
    rm /var/cache/apk/* && \
    chmod ugo+x /usr/local/bin/*.sh
    
CMD ["/usr/local/bin/runS3OnBatch.sh" ]
