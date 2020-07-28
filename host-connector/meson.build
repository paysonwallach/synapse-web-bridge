project(
  'synapse-firefox-host-connection',
  'vala',
  'c',
  license: ['GPL2', 'LGPL2.1'],
  meson_version: '>=0.50.0',
  version: '0.2.99.4'
)

app_name = 'com.paysonwallach.synapse-firefox.connector'

vala = meson.get_compiler('vala')

glib_dep = dependency('glib-2.0')
glib_json_dep = dependency('json-glib-1.0')
gio_dep = dependency('gio-2.0')
gio_unix_dep = dependency('gio-unix-2.0')
granite_dep = dependency('granite')
posix_dep = vala.find_library('posix')

executable (
  app_name,
  files(
    'src/Main.vala'
  ),
  dependencies: [
    glib_dep,
    glib_json_dep,
    gio_dep,
    gio_unix_dep,
    granite_dep,
    posix_dep
  ],
  install: false
)
