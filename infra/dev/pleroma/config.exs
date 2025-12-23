# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
import Config

config :pleroma, Pleroma.Web.Endpoint,
  url: [host: System.get_env("DOMAIN", "localhost"), scheme: "https", port: 443],
  http: [ip: {0, 0, 0, 0}, port: 4000]

config :pleroma, :instance,
  federating: true,
  registrations_open: true

config :cors_plug,
  origin: ["http://pleroma.tstt.dev", "https://pleroma.tstt.dev"]

config :pleroma, Pleroma.Emails.Mailer, enabled: false

config :pleroma, Pleroma.Captcha, enabled: false

config :pleroma, Pleroma.Web.Plugs.RemoteIp, enabled: false
config :pleroma, :rate_limit, nil

config :pleroma, Pleroma.Emails.Mailer, adapter: Swoosh.Adapters.Local

config :logger, :console, level: :debug
config :logger, :ex_syslogger, level: :debug
