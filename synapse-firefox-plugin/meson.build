project(
  'synapse-firefox-plugin',
  'vala',
  'c',
  license: ['GPL2', 'LGPL2.1'],
  meson_version: '>=0.50.0',
  version: '0.2.99.4'
)

add_project_arguments('-DWNCK_I_KNOW_THIS_IS_UNSTABLE', language: 'c')

prefix = get_option('prefix')
lib_dir = join_paths(prefix, get_option('libdir'))
data_dir = join_paths(prefix, get_option('datadir'))
pkglib_dir = join_paths(lib_dir, meson.project_name())
plugins_dir = join_paths(pkglib_dir, 'plugins')

gee_version = '>=0.5.2'
glib_version = '>=2.40.0'
gtk_version = '>=3.0.0'

gdk_dep = dependency('gdk-x11-3.0', version: gtk_version)
gee_dep = dependency('gee-0.8', version: gee_version)
gio_dep = dependency('gio-2.0', version: glib_version)
glib_dep = dependency('glib-2.0', version: glib_version)
gtk_dep = dependency('gtk+-3.0', version: gtk_version)
glib_json_dep = dependency('json-glib-1.0')
synapse_dep = dependency('synapse-1.0')
wnck_dep = dependency('libwnck-3.0')

shared_library(
  'firefoxplugin',
  files(
    'src/Main.vala'
  ),
  dependencies: [
    gdk_dep,
    gee_dep,
    gio_dep,
    glib_dep,
    gtk_dep,
    glib_json_dep,
    synapse_dep,
    wnck_dep
  ],
  install: true,
  install_dir: plugins_dir
)
