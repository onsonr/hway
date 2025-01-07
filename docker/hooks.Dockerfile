# Stage 0: Build the thing
# Need debian based image to build the native rust module
# as musl doesn't support cdylib
FROM node:20-slim AS builder

ARG GIT_SOURCE_REPO="https://github.com/matrix-org/matrix-hookshot.git"
ARG GIT_SOURCE_BRANCH="main"

# Needed in order to build rust FFI bindings.
RUN apt-get update && apt-get install -y build-essential cmake curl pkg-config pkg-config libssl-dev git

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

# arm64 builds consume a lot of memory if `CARGO_NET_GIT_FETCH_WITH_CLI` is not
# set to true, so we expose it as a build-arg.
ARG CARGO_NET_GIT_FETCH_WITH_CLI=false
ENV CARGO_NET_GIT_FETCH_WITH_CLI=$CARGO_NET_GIT_FETCH_WITH_CLI

RUN git clone -b $GIT_SOURCE_BRANCH $GIT_SOURCE_REPO /src
WORKDIR /src
RUN yarn config set yarn-offline-mirror /cache/yarn
RUN yarn --ignore-scripts --pure-lockfile --network-timeout 600000

# Workaround: Need to install esbuild manually https://github.com/evanw/esbuild/issues/462#issuecomment-771328459
RUN node node_modules/esbuild/install.js
RUN yarn build


# Stage 1: The actual container
FROM node:20-slim

WORKDIR /bin/matrix-hookshot

RUN apt-get update && apt-get install -y openssl ca-certificates

COPY --from=builder /src/yarn.lock /src/package.json ./
COPY --from=builder /cache/yarn /cache/yarn
RUN yarn config set yarn-offline-mirror /cache/yarn

RUN yarn --network-timeout 600000 --production --pure-lockfile && yarn cache clean

COPY --from=builder /src/lib ./
COPY --from=builder /src/public ./public
COPY --from=builder /src/assets ./assets

COPY apps/hooks.sonr.chat/registration.yml /data/registration.yml
COPY apps/hooks.sonr.chat/passkey.pem /data/passkey.pem
COPY config/hookshot.yml /data/config.yml

ENV NODE_ENV="production"

VOLUME /data
EXPOSE 9993
EXPOSE 7775

CMD ["node", "/bin/matrix-hookshot/App/BridgeApp.js", "/data/config.yml", "/data/registration.yml"]
