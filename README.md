# Kazarma

## A Matrix-ActivityPub bridge

A Matrix bridge to ActivityPub. It uses [this ActivityPub library](https://github.com/commonspub/ActivityPub) and [those](https://gitlab.com/kazarma/matrix_app_service.ex) Matrix [libraries](https://gitlab.com/uhoreg/polyjuice_client).

![overview](doc_diagrams/overview.png)

## Resources

- [API documentation](https://kazarma.gitlab.io/matrix_app_service.ex)
- [Matrix](https://matrix.to/#/#kazarma:matrix.org?via=matrix.asso-fare.fr&via=matrix.org&via=t2bot.io)

## Development environment

### Using [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/)

```bash
git submodule update --init --recursive
docker-compose run synapse generate
docker-compose run kazarma mix do deps.get, ecto.setup
docker-compose up
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
docker-compose rm -fs postgres_kazarma postgres_pleroma synapse
docker volume rm kazarma_postgres_pleroma_files kazarma_postgres_kazarma_files kazarma_synapse_files
docker-compose run synapse generate
docker-compose run kazarma mix ecto.setup
```

### Locally

```bash
git submodule update --init --recursive
mix do deps.get, ecto.setup
iex -S mix phx.server
```

## Generate documentation

We use [ditaa](http://ditaa.sourceforge.net) to generate diagrams and integrate
them into HexDoc. To edit diagrams use [asciiflow](http://asciiflow.com/) and paste
the result in HTML files in the `doc_diagrams` folder.

```bash
rm doc_diagrams/*.png && ditaa doc_diagrams/*.html
mix docs
```

## Run tests

```bash
mix test
```

## Sponsors

The [NLNet foundation](https://nlnet.nl/) [selected this project](https://nlnet.nl/project/Matrix-CommonsPub/) as part of the Next Generation Internet initiative (thank you!).

They redistribute public European funding (EU'S R&D programme called "Horizon 2020") to finance programming efforts on a "resilient, trustworthy and sustainable" Internet. if you're interested, [check out how to apply in this video](https://media.ccc.de/v/36c3-10795-ngi_zero_a_treasure_trove_of_it_innovation)!
