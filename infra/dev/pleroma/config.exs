# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
import Config

config :pleroma, Pleroma.Web.Endpoint,
  url: [host: System.get_env("DOMAIN", "localhost"), scheme: "http", port: 80],
  http: [ip: {0, 0, 0, 0}, port: 4000]

config :pleroma, :instance,
  federating: true,
  registrations_open: true

config :cors_plug,
  origin: ["http://pleroma.com", "https://pleroma.com"]

config :pleroma, Pleroma.Emails.Mailer, enabled: false

config :pleroma, Pleroma.Captcha, enabled: false

config :pleroma, Pleroma.Web.Plugs.RemoteIp, enabled: false
config :pleroma, :rate_limit, nil

config :logger, :console, level: :warn
config :logger, :ex_syslogger, level: :warn
