# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#

config :server,
  # Game Options
  version_major: 95,
  version_minor: "1",
  locale: 8,
  key: <<0x13, 0x00, 0x00, 0x00,
         0x08, 0x00, 0x00, 0x00,
         0x06, 0x00, 0x00, 0x00,
         0xB4, 0x00, 0x00, 0x00,
         0x1B, 0x00, 0x00, 0x00,
         0x0F, 0x00, 0x00, 0x00,
         0x33, 0x00, 0x00, 0x00,
         0x52, 0x00, 0x00, 0x00>>,
  # Other options
  tickrate: 50

config :logger, :console,
       metadata: [:file, :line]
