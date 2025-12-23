# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only

FROM elixir:1.19-otp-28

ENV HEX_HTTP_CONCURRENCY=1
ENV HEX_HTTP_TIMEOUT=240
ENV MIX_ENV=dev

# Cache elixir deps
# COPY ./mix.exs ./mix.lock /opt/app/
# COPY ./config /opt/app/config/
# COPY ./activity_pub /opt/app/activity_pub/
# COPY ./matrix_app_service /opt/app/matrix_app_service
# COPY ./polyjuice_client /opt/app/polyjuice_client
# RUN mix do deps.get, deps.compile

# Same with npm deps
# COPY ./assets /opt/app/assets/
# COPY ./assets/package.json /opt/app/assets/
# RUN cd assets && \
#     npm install --ignore-optional

# ADD . .

# Run frontend build, compile, and digest assets
# RUN cd assets/ && \
#     npm run deploy && \
#     cd - && \
#     mix do compile, phx.digest

# COPY ./lib /opt/app/lib/
# COPY ./priv /opt/app/priv/
# RUN mix compile

# VOLUME ["/opt/app/lib"]
# VOLUME ["/opt/app/assets"]
# VOLUME ["/opt/app/priv"]

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force \
  && mix local.rebar --force

## Add the wait script to the image
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.6.0/wait /wait
RUN chmod +x /wait

# Set exposed ports
EXPOSE 4000

# temporary fix
# RUN chmod -R 777 /opt/app/_build

# temporary fix
# USER default

CMD /wait && mix phx.server
