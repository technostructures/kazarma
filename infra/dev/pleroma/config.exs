import Config

config :pleroma, Pleroma.Web.Endpoint,
  url: [host: System.get_env("DOMAIN", "localhost"), scheme: "http", port: 80],
  http: [ip: {0, 0, 0, 0}, port: 4000]

config :pleroma, :instance,
  federating: true,
  registrations_open: true

config :cors_plug,
  origin: ["http://pleroma.local", "https://pleroma.local"]

config :pleroma, Pleroma.Captcha, enabled: false

config :pleroma, Pleroma.Web.Plugs.RemoteIp, enabled: false

config :logger, :console, level: :warn
config :logger, :ex_syslogger, level: :warn
