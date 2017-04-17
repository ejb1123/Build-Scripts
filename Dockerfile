FROM mono:4.8
RUN apt-get update && \
    apt-get install -y p7zip
WORKDIR /opt/sandbox
#VOLUME /opt/sandbox
#RUN prep.py
ADD scripts/prep.sh prep.sh
CMD ["/bin/bash","prep.sh"]
