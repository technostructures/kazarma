# Changelog

## [1.0.0-alpha.1]

### Features

#### Users and profiles

- Dynamic creation of Matrix puppets corresponding to ActivityPub Users
- Dynamic creation of ActivityPub puppets corresponding to Matrix Users
- Bidirectional update of display name and avatar

#### Generic bridging

- Mentions
- Deletions
- Attachments
- Replies
- Handling of activities: Post, Video and Event

#### Private messages

- Mastodon-like DMs using private (non-direct) rooms
- Pleroma-like chat using private (direct) rooms

#### Bridging of public activities from ActivityPub

- Opt-in using a follow of the relay actor, creates a public room
- Possibility of following by sending `!kazarma follow`
- Sending a message to the room automatically adds a mention
- Blocking from ActivityPub bans from the room
- Mentioning a Matrix user from ActivityPub invites them to the room if it exists

#### Bridging of a Matrix outbox to ActivityPub

- Creation of an outbox by inviting the kazarma bot and sending `!kazarma outbox`
- Possibility of following by sending `!kazarma follow`
- Sending a message to the room (by other users) automatically adds a mention

#### Specific ActivityPub implementations: Mobilizon groups

- Opt-in federation using instance follows
- Adding a Matrix user to a group creates a private group and invites them
- Matrix users accept the invitation by joining the room
- Removing them from the group bans them from the room
- The room is used for group discussions

#### Web front-end

- Search for a Matrix ID / AP ID / AP username
- Displays any user on ActivityPub or Matrix with their corresponding puppet on the other network
- Shows wether ActivityPub users have enabled public activity bridging
- Shows public activities from Matrix users that have activated their outbox room
- French and Spanish translations
- Integrated help

#### Deployment

- OCI image based on Alpine
- Helm chart
- Documentation on [https://docs.kazar.ma](https://docs.kazar.ma)
