Office Maker Simple Server
----

## Requirement

You need to have MySQL and [Node.js](https://nodejs.org/) (>= 4.0) installed.


## Setup

### Install

Currently, installation is done by client project for ease.

<!--
```
npm install
```
-->

### Initialize

To initialize DB, execute SQL in `sql` folder.

```
node commands.js createDataForDebug
```

There are also other commands in commands.js.

```
node commands.js [commandName] [args]
```

## Start Server

Currently, server operations are handled by client project for ease.


## Configuration

Copy [defaultConfig.json] and rename to `config.json`.

|name||
|:--|:--|
|mysql.host||
|mysql.user||
|mysql.pass||
|title|This name is used by header.|
|accountServiceRoot|URL of account service. http://xxx.xxx.xx.xx/accounts |
|profileServiceRoot|URL of account service. http://xxx.xxx.xx.xx/profiles |
|secret|The path of account service's public key file. path/to/pubkey.pem |

## REST API

API is defined by client. See [here](../../README.md).


### Table Definition

See [here](./sql/2-create-tables.sql).


## License

[Apache License 2.0](LICENSE)