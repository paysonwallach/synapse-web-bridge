<div align="center">
  <h1>Synapse Web Bridge</h1>
  <p>Firefox addon for Synapse</p>
  <a href="https://github.com/paysonwallach/synapse-web-bridge/releases/latest">
    <img alt="Version 0.1.0" src="https://img.shields.io/badge/version-0.1.0-red.svg?cacheSeconds=2592000&style=flat-square" />
  </a>
  <a href="https://github.com/paysonwallach/synapse-web-bridge/blob/master/LICENSE" target="\_blank">
    <img alt="Licensed under the GNU General Public License v3.0" src="https://img.shields.io/github/license/paysonwallach/synapse-web-bridge?style=flat-square" />
  <a href=https://buymeacoffee.com/paysonwallach>
    <img src=https://img.shields.io/badge/donate-Buy%20me%20a%20coffe-yellow?style=flat-square>
  </a>
  <br>
  <br>
</div>

## Installation

Clone this repository or download the [latest release](https://github.com/paysonwallach/synapse-web-bridge/releases/latest).

```shell
git clone https://github.com/paysonwallach/synapse-web-bridge
```

Configure the build directory at the root of the project.

```shell
meson --prefix=/usr build
```

To use [Synapse Web Bridge](https://github.com/paysonwallach/synapse-web-bridge) with a browser extension, set the `browsers` option accordingly, and the appropriate manifests will be generated and installed in their respective locations. For example, with Firefox:

```shell
meson --prefix=/usr -Dbrowsers=["firefox"] build
```

Install with `ninja`.

```shell
ninja -C build install
```

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change. By participating in this project, you agree to abide by the terms of the [Code of Conduct](https://github.com/paysonwallach/synapse-web-bridge/blob/master/CODE_OF_CONDUCT.md).

## License

[Synapse Web Bridge](https://github.com/paysonwallach/synapse-web-bridge) is licensed under the [GNU General Public License v3.0](https://github.com/paysonwallach/synapse-web-bridge/blob/master/LICENSE).
