FROM python:3.11-slim as build

# COPY custom-root-ca.crt /usr/local/share/ca-certificates
# RUN update-ca-certificates

ARG NWRFC_ZIP
ARG SAPCAR_EXE
ARG CRYPTOLIB_SAR

# Setup OS stuff
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get update && apt-get upgrade -y && apt-get install -y python3-dev uuid uuid-runtime gcc g++ unzip

# Copy SAP tools
#COPY nwrfc750P_12-70002752.zip .
COPY ${NWRFC_ZIP} .
#COPY SAPCAR .
COPY ${SAPCAR_EXE} .
#COPY SAPCRYPTOLIBP_8551-20011697.SAR .
COPY ${CRYPTOLIB_SAR} .
RUN chmod u+x ${SAPCAR_EXE}


# Prepare RFC library
RUN mkdir -p /usr/local && cd /usr/local && unzip /${NWRFC_ZIP}
RUN mkdir /sec && cd sec && /${SAPCAR_EXE} -xf /${CRYPTOLIB_SAR}

ENV SAPNWRFC_HOME /usr/local/nwrfcsdk
ENV LD_LIBRARY_PATH=/usr/local/nwrfcsdk/lib:${LD_LIBRARY_PATH}

# Install python libraries

RUN python -m venv /opt/venv
# Enable venv
ENV PATH="/opt/venv/bin:$PATH"

# RUN pip install --cert=/usr/local/share/custom-root-ca.crt install truststore
# RUN pip config set global.use-feature truststore
RUN pip install pyrfc

# Setup SNC PSE
ENV SECUDIR /sec
RUN --mount=type=secret,id=key,required=true,dst=/run/secrets/key.p12 --mount=type=secret,id=pass,required=true \
  cd /sec && \
  ./sapgenpse import_p12 -x $(cat /run/secrets/pass) -z $(cat /run/secrets/pass) -p rfc.pse /run/secrets/key.p12

FROM python:3.11-slim as run

COPY --from=build /usr/local/nwrfcsdk /usr/local/nwrfcsdk
COPY --from=build /sec /sec
COPY --from=build /opt/venv /opt/venv

RUN useradd -u 2000 pyrfc && \
  chown -R pyrfc /sec
USER pyrfc

ENV PATH="/opt/venv/bin:$PATH"
ENV SAPNWRFC_HOME /usr/local/nwrfcsdk
ENV LD_LIBRARY_PATH=/usr/local/nwrfcsdk/lib:${LD_LIBRARY_PATH}
ENV SECUDIR /sec

RUN --mount=type=secret,uid=2000,id=pass,required=true \
  cd $SECUDIR && \
  ./sapgenpse seclogin -x $(cat /run/secrets/pass) -p rfc.pse && \
  chmod 400 ${SECUDIR}/rfc.pse

ENTRYPOINT [ "python" ]

CMD "pyrfc-test.py"