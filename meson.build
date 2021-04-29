project(
  'com.paysonwallach.synapse.plugins.web.bridge',
  'vala',
  'c',
  license: 'GPL-3.0',
  meson_version: '>=0.50.0',
  version: '0.1.0'
)

vala = meson.get_compiler('vala')

glib_dep = dependency('glib-2.0')
glib_json_dep = dependency('json-glib-1.0')
gio_dep = dependency('gio-2.0')
gio_unix_dep = dependency('gio-unix-2.0')
posix_dep = vala.find_library('posix')

add_project_arguments([
    '-DG_LOG_DOMAIN="@0@"'.format(meson.project_name())
  ],
  language:'c'
)

executable (
  meson.project_name(),
  files(
    'src/Main.vala'
  ),
  dependencies: [
    glib_dep,
    glib_json_dep,
    gio_dep,
    gio_unix_dep,
    posix_dep
  ],
  install: true
)

meson.add_install_script(
  'meson/post_install.py',
  get_option('browsers')
)
