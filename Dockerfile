#############
FROM ubuntu:22.04
############

########################################
RUN apt-get update && apt-get install -y systemctl ipcalc apache2 curl jq parallel
RUN mkdir -p /opt/dedoduro && mkdir -p /opt/dedoduro/logs
########################################

#######################################
COPY services/* /etc/systemd/system/
COPY dedoduro.sh /opt/dedoduro/
COPY start.sh /opt/dedoduro/
COPY config.cfg /opt/dedoduro/
#######################################

#######################################
RUN chmod +x /opt/dedoduro/start.sh
########################################

########################################
USER root
########################################

########################################
LABEL description="MINA"
LABEL version="0.1"
########################################

########################################
ENTRYPOINT ["/opt/dedoduro/start.sh"]
########################################

########################################
CMD [ "sleep", "infinity" ]
########################################
