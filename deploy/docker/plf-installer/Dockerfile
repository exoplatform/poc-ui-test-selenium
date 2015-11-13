FROM       exoplatform/ubuntu-jdk7:7u71

# TODO use exo user
# ENV EXO_USER exo
# ENV EXO_GROUP ${EXO_USER}

# Install some useful or needed tools
RUN apt-get update
RUN  apt-get -y upgrade
RUN  apt-get -y install libxml-xpath-perl zip
#  apt-get -qq -y autoremove && \
#  apt-get -qq -y autoclean \
RUN apt-get install -y time

RUN  mkdir /scripts
  ## Not needed on the installer
  # libreoffice-calc libreoffice-draw libreoffice-impress libreoffice-math libreoffice-writer && \

# USER ${EXO_USER}

WORKDIR /scripts

VOLUME /downloads

ENTRYPOINT ["/scripts/installInstance.sh"]


COPY [ "_downloadPLF.sh", "_functions.sh", "_functions_download.sh", "_setenv.sh", "installInstance.sh", "/scripts/" ]
