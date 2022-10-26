# Kazarma

[![Latest Release](https://gitlab.com/kazarma/kazarma/-/badges/release.svg)](https://gitlab.com/kazarma/kazarma/-/releases)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/kazarma)](https://artifacthub.io/packages/helm/kazarma/kazarma)
[![Matrix room](https://img.shields.io/matrix/kazarma:matrix.org)](https://matrix.to/#/#kazarma:matrix.org?via=matrix.org)
[![REUSE status](https://api.reuse.software/badge/gitlab.com/kazarma/kazarma)](https://api.reuse.software/info/gitlab.com/kazarma/kazarma)
[![Gitlab pipeline status](https://img.shields.io/gitlab/pipeline-status/kazarma/kazarma?branch=main)](https://gitlab.com/kazarma/kazarma/-/pipelines)
[![coverage report](https://gitlab.com/kazarma/kazarma/badges/main/coverage.svg)](https://gitlab.com/kazarma/kazarma/-/commits/main)

A Matrix bridge to ActivityPub. It uses [this ActivityPub library](https://github.com/commonspub/ActivityPub) and [those](https://gitlab.com/kazarma/matrix_app_service.ex) Matrix [libraries](https://gitlab.com/uhoreg/polyjuice_client).

## [User guide](https://docs.kazar.ma/category/user-guide)

![overview](doc_diagrams/overview.png)

## Installation

### [Erlang release](https://docs.kazar.ma/administrator-guide/docker-compose)

### [Docker Compose](https://docs.kazar.ma/administrator-guide/docker-compose)

### [Helm](https://docs.kazar.ma/administrator-guide/docker-compose)

## Application service configuration

The application service configuration file for your Matrix server should look like this (`url` points to your Kazarma instance, with the `/matrix` route):

```yaml
id: "Kazarma"
url: "https://kazarma.domain/matrix/"
as_token: "change_this"
hs_token: "change_this"
sender_localpart: "_kazarma"
namespaces:
  aliases:
    - exclusive: true
      regex: "#_ap_.+=.+:matrix_domain"
  users:
    - exclusive: true
      regex: "@_ap_.+=.+:matrix_domain"
```

## Configuration

- `DATABASE_URL`: URL with `ecto://` scheme (`ecto://user:password@host:database`), as explained [here](https://hexdocs.pm/ecto/Ecto.Repo.html#module-urls)
- `SECRET_KEY_BASE`: Phoenix's secret key base, used to sign session cookies. With Mix and Phoenix, it can be easily generated with `mix phx.gen.secret`.
- `HOMESERVER_TOKEN`: Token defined in the application service configuration file, will be used to authenticate the Matrix server against Kazarma.
- `ACCESS_TOKEN`: Token defined in the application service configuration file, will be used to authenticate Kazarma against the Matrix server.
- `MATRIX_URL`: URL to the Matrix server.
- `HOST`: Host for the Kazarma application, used to generate URLs.
- `ACTIVITY_PUB_DOMAIN`: ActivityPub domain for actors. If different than the host, you need to serve a file at `domain/.well-known/host-meta`, containing a link to the real host, like [this](./infra/dev/delegation/host-meta)
- `PUPPET_PREFIX`: Username prefix for Matrix puppet users that correspond to ActivityPub real actors.
- `BRIDGE_REMOTE`: True or false, wether Kazarma should bridge Matrix users from different homeservers (than the one beside Kazarma), to the ActivityPub network.
- `HTML_SEARCH`: True or false, wether to show the search field on Kazarma HTML pages.
- `HTML_AP`: True or false, wether to display profiles for ActivityPub actors. It can help Matrix users to get the (puppet) Matrix ID to reach an ActivityPub actor.

## Development environment

### Using [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/)

```bash
git submodule update --init --recursive
docker compose run --rm synapse generate
docker compose run --rm kazarma mix do deps.get, ecto.setup
docker compose run --rm kazarma npm --prefix assets install
docker compose up
```

On Linux, use `docker-hoster` to make container domains accessible:
```
docker run -d \
    -v /var/run/docker.sock:/tmp/docker.sock \
    -v /etc/hosts:/tmp/hosts \
    --name docker-hoster \
    dvdarias/docker-hoster@sha256:2b0e0f8155446e55f965fa33691da828c1db50b24d5916d690b47439524291ba
```

(after rebooting, you will need to start it again using `docker start docker-hoster`)

This should run containers with those services:

- [kazarma.kazarma.local](http://kazarma.kazarma.local) -> Kazarma itself
- [matrix.kazarma.local](http://matrix.kazarma.local) -> Matrix server
- [kazarma.local](http://kazarma.local) -> serves .well-known routes that allow
  Matrix and Kazarma.ActivityPub to use simple `kazarma.local` domain (for
  users, etc)
- [pleroma.local](http://pleroma.local) -> Pleroma, should be able to address
  Matrix users using `kazarma.local` domain
- [element.local](http://element.local) -> Element, will connect to Synapse,
  should then be able to address Pleroma users using `pleroma.local` domain

You can also start an IEx console:

```bash
docker compose run --rm kazarma iex -S mix
```

#### On macOS

On macOS, instead of `docker-hoster` you need to add the following domains to your `/etc/hosts` file:
```
# Kazarma development domains
127.0.0.1 kazarma.local
127.0.0.1 kazarma.kazarma.local
127.0.0.1 matrix.kazarma.local
127.0.0.1 pleroma.local
127.0.0.1 element.local
```

Then the `docker-compose.yml` file should (at least) expose the `80` port in the `traefik` container:

```yaml
  traefik:
    image: traefik:v2.2.0
    ports:
      - 80:80
      - 443:443
```

#### Reset databases

```bash
docker compose rm -fs postgres_kazarma postgres_pleroma synapse
docker volume rm kazarma_postgres_pleroma_files kazarma_postgres_kazarma_files kazarma_synapse_files
docker compose run --rm synapse generate
docker compose run --rm kazarma mix ecto.setup
```

### Locally

```bash
git submodule update --init --recursive
mix do deps.get, ecto.setup
iex -S mix phx.server
```

## Run tests

```bash
mix test
```

## Generate documentation

We use [ditaa](http://ditaa.sourceforge.net) to generate diagrams and integrate them into HexDoc. To edit diagrams use [asciiflow](http://asciiflow.com/) and paste the result in HTML files in the `doc_diagrams` folder.

```bash
rm doc_diagrams/*.png && ditaa doc_diagrams/*.html
mix docs
```

## Sponsors

The [NLNet foundation](https://nlnet.nl/) [selected this project](https://nlnet.nl/project/Matrix-CommonsPub/) as part of the Next Generation Internet initiative (thank you!).

They redistribute public European funding (EU'S R&D programme called "Horizon 2020") to finance programming efforts on a "resilient, trustworthy and sustainable" Internet. if you're interested, [check out how to apply in this video](https://media.ccc.de/v/36c3-10795-ngi_zero_a_treasure_trove_of_it_innovation)!


## License 

This project is available as open source under the terms of the AGPLv3. For accurate information, please check individual files.
