FROM golang:1.20-alpine3.16 as go-builder
RUN apk --no-cache add git

ARG CGO_ENABLED=0

WORKDIR /go/src/omnia
ARG ETHSIGN_REF="tags/v1.13.3"
RUN git clone https://github.com/chronicleprotocol/omnia.git . \
  && git checkout --quiet ${ETHSIGN_REF} \
  && cd ethsign \
  && go mod vendor \
  && go build .

# Building gofer & spire
WORKDIR /go/src/oracle-suite
ARG ORACLE_SUITE_REF="tags/upshotv0.10.3"
RUN git clone https://github.com/soodup/oracle-suite.git . \
  && git checkout --quiet ${ORACLE_SUITE_REF}

RUN go mod vendor \
    && go build ./cmd/spire \
    && go build ./cmd/gofer

# SSB Go client have been moved to new repo
WORKDIR /go/src/ssb
ARG SSB_RPC_CLIENT_REF="tags/v0.1.1"
RUN git clone https://github.com/chronicleprotocol/ssb.git . \
  && git checkout --quiet ${SSB_RPC_CLIENT_REF}

RUN cd ssb-rpc-client && \
  go mod vendor \
  && go build .

FROM omnia-base-upshot

RUN apk add --update --no-cache \
  jq curl git make perl g++ ca-certificates tree \
  bash bash-doc bash-completion \
  util-linux pciutils usbutils coreutils binutils findutils grep iproute2 \
  && apk add --no-cache -X https://dl-cdn.alpinelinux.org/alpine/edge/testing \
  agrep datamash

COPY --from=go-builder \
  /go/src/omnia/ethsign/ethsign \
  /go/src/oracle-suite/spire \
  /go/src/oracle-suite/gofer \
  /go/src/ssb/ssb-rpc-client/ssb-rpc-client \
  /usr/local/bin/

COPY ./bin /opt/omnia/bin
COPY ./config /opt/omnia/config
COPY ./exec /opt/omnia/exec
COPY ./lib /opt/omnia/lib
COPY ./version /opt/omnia/version

# Installing setzer
ARG SETZER_REF="tags/v0.7.0"
RUN git clone https://github.com/chronicleprotocol/setzer.git \
  && cd setzer \
  && git checkout --quiet ${SETZER_REF} \
  && mkdir /opt/setzer/ \
  && cp -R libexec/ /opt/setzer/libexec/ \
  && cp -R bin /opt/setzer/bin \
  && cd .. \
  && rm -rf setzer

ENV HOME=/home/omnia

ENV OMNIA_CONFIG=/opt/omnia/config/relay.json \
  SPIRE_CONFIG=${HOME}/spire.hcl \
  GOFER_CONFIG=${HOME}/gofer.hcl \
  ETH_RPC_URL=http://geth.local:8545 \
  ETH_GAS=7000000 \
  CHLORIDE_JS='1'

COPY ./docker/spire/config/client.hcl ${SPIRE_CONFIG}
COPY ./docker/gofer/client.hcl ${GOFER_CONFIG}

WORKDIR ${HOME}
COPY ./docker/keystore/ .ethereum/keystore/
# COPY ./omnia/docker/ssb-server/config/manifest.json .ssb/manifest.json
# COPY ./omnia/docker/ssb-server/config/secret .ssb/secret
# COPY ./omnia/docker/ssb-server/config/config.json .ssb/config

ARG USER=1000
ARG GROUP=1000
RUN chown -R ${USER}:${GROUP} ${HOME}
USER ${USER}:${GROUP}

# Removing notification from `parallel`
RUN printf 'will cite' | parallel --citation 1>/dev/null 2>/dev/null; exit 0

# Setting up PATH for setzer and omnia bin folder
# Here we have set of different pathes included:
# - /opt/setzer - For `setzer` executable
# - /opt/omnia/bin - Omnia executables
# - /opt/omnia/exec - Omnia transports executables
ENV PATH="/opt/setzer/bin:/opt/omnia/bin:/opt/omnia/exec:${PATH}"

CMD ["omnia"]
