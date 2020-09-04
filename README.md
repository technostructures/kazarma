# Kazarma
## A Matrix-ActivityPub bridge
A [Matrix bridge](https://matrix.org/docs/guides/types-of-bridging) between [Matrix's Application Services](https://matrix.org/docs/guides/application-services) [API](https://matrix.org/docs/spec/application_service/r0.1.2) and ActivityPub through the [Elixir library CommonsPub](https://gitlab.com/matrix-appservice-commonspub/CommonsPub). Previously called matrix-appservice-commonspub.

This project is composed of 3 sub-projects:

- [CommonsPub](https://commonspub.org/) [fork](https://gitlab.com/matrix-appservice-commonspub/commonspub), enabling Elixir apps to implement the ActivityPub standard
- [matrix-appservice API wrapper](https://gitlab.com/matrix-appservice-commonspub/matrix_app_service.ex) in [Elixir](https://elixir-lang.org/) / Phoenix (web framework for Elixir)
- a Matrix-ActivityPub bridge using CommonsPub and the Matrix-AppService API wrapper (this repo)

## Using Docker

```bash
docker-compose run synapse generate
docker-compose run kazarma mix ecto.setup
docker-compose up
```

## Current state

WebFinger implemented.

## Learn more

### Architecture

#### Matrix Application Services API <-> ActivityPub endpoints and publishing

Example message request:
```js
PUT /transactions/{id}                    =>   newActivity({type: Create, object: {type: Note, content: "@bob@distantserver blahblah"}, from: @alice@server, actor: @bob@distantserver}
{ from: @alice:server,
  to: roomWith([@_ap@bob@distantserver:server])
}
```

#### ActivityPub Server-to-Server (S2S) <--> Matrix Client-to-Server (C2S) as appservice

Example message request:
```js
POST /alice/inbox                         =>  newMessage({from: @_ap@bob@distantserver:server, to: createOrGetRoom({with: @alice:server})
{ from: @bob@distantserver }
```

### Matrix

- Matrix Application Services docs: https://matrix.org/docs/guides/application-services/
- Matrix Application Services API specification: https://matrix.org/docs/spec/application_service/unstable
- matrix-appservice-bridge: https://github.com/matrix-org/matrix-appservice-bridge/
- MXToot - Matrix-Mastodon bot written in Java: https://github.com/ma1uta/mxtoot
- [Polyjuice Matrix client library](https://hexdocs.pm/polyjuice_client/readme.html): https://gitlab.com/uhoreg/polyjuice_client/blob/master/lib/polyjuice/client/endpoint.ex

### ActivityPub

- W3C ActivityPub reference: https://www.w3.org/TR/activitypub/
- [blogpost on reading AP](https://tinysubversions.com/notes/reading-activitypub/)
- [talk on getting a working AP implementation to talk to mastodon](https://conf.tube/videos/watch/56c17fb8-bf55-4963-9d4e-e6345bee8de4)
- [CommonsPub official website](commonspub.org/)

- [Go library](https://github.com/go-fed) for handling ActivityPub
- [express-activitypub](https://github.com/dariusk/express-activitypub): A very simple reference implementation of an ActivityPub server using Express.js

### Elixir/Phoenix
- Elixir official website: https://elixir-lang.org/
- Phoenix Docs: https://hexdocs.pm/phoenix
- Phoenix Guides: https://hexdocs.pm/phoenix/overview.html


## Sponsors
The [NLNet foundation](https://nlnet.nl/) [selected this project](https://nlnet.nl/project/Matrix-CommonsPub/) as part of the Next Generation Internet initiative (thank you!).

They redistribute public European funding (EU'S R&D programme called "Horizon 2020") to finance programming efforts on a "resilient,trustworthy and sustainable" Internet. if you're interested, [check out how to apply in this video](https://media.ccc.de/v/36c3-10795-ngi_zero_a_treasure_trove_of_it_innovation)!

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
