# fritzportforward

A tool on basis of [fritzconnection](https://github.com/kbr/fritzconnection) that allows to list and modify port forwardings on a FritzBox.

## How to use/build
For the basic setup you need [pipenv](https://github.com/pypa/pipenv):
```
pip install pipenv # if you haven't installed it already.
pipenv --python 3
pipenv install
```

Now you can either step into a pipenv shell
```
pipenv shell
``` 
or call the tool directly:
```
$ pipenv run ./fritzportforward --help

usage: fritzportforward [-h] [-i [ADDRESS]] [--port [PORT]] [-u [USERNAME]] [-p [PASSWORD]] [-e [ENCRYPT]] [-x] [-y] [--cache-format [CACHE_FORMAT]] [--cache-directory [CACHE_DIRECTORY]] [-m MAPPING] [-l]
                        [-D] [-U] [-P PROTOCOL] [-n DESCRIPTION] [--trace-on-error]

This tool allows you to list and modify portmappings of your FritzBox. But you are limited to add and change only portmappings for the host the script is called from. The reason is the Fritz Box' UPnP
interface. Unfortunately you cannot delete mappings. Be aware: If you want to modify a mapping but you provide arguments that don't match an existing mapping, a new one is created.

optional arguments:
  -h, --help            show this help message and exit
  -i [ADDRESS], --ip-address [ADDRESS]
                        Specify ip-address of the FritzBox to connect to. Default: 169.254.1.1
  --port [PORT]         Port of the FritzBox to connect to. Default: 49000
  -u [USERNAME], --username [USERNAME]
                        Fritzbox authentication username
  -p [PASSWORD], --password [PASSWORD]
                        Fritzbox authentication password
  -e [ENCRYPT], --encrypt [ENCRYPT]
                        Flag: use secure connection (TLS)
  -x, --use-cache       Flag: use api cache (e[x]cellerate: speed-up subsequent instanciations)
  -y, --suppress-cache-verification
                        Flag: suppress cache verification, implies -x
  --cache-format [CACHE_FORMAT]
                        cache-file format: json|pickle (default: pickle)
  --cache-directory [CACHE_DIRECTORY]
                        path to cache directory (default: ~.fritzconnection)
  -m MAPPING, --mapping MAPPING
                        The basic data of a mapping<external port>:<internal port>
  -l, --list            Prints out a list of the currently defined portmappings.
  -D, --disable         Disable or add a mapping. Removing one is not supported. Depends on --mapping and --protocol (default: TCP).
  -U, --update          Depends on --mapping and --protocol (default: TCP), but uses also --name and --disable (where is default: active).
  -P PROTOCOL, --protocol PROTOCOL
                        Either TCP or UDP.
  -n DESCRIPTION, --description DESCRIPTION
                        A description or name of the mapping.
  --trace-on-error      Print stack trace on exceptions (for debugging).

``` 

## Installation
To install the tool on your system call `./install.sh`. 
As root all files will be placed under `/usr/local/(bin|share)`. As user under `~/.local/(bin/share)`.

The following tools will be available in your installation bin directory:
```
fritzcall
fritzconnection
fritzhomeauto
fritzhosts
fritzmonitor
fritzphonebook
fritzportforward
fritzstatus
fritztools
fritzwlan
```

The app `fritztools` allows some simple admin tasks, like:
```
Usage: fritztools [Options]
   --uninstall          Uninstall the fritztools
   -y                   Answer with 'yes' to uninstall
   --config             Setup configuration for connecting to FritzBox
   --bash-completion    Provides functions for bash completion. 
                        Do: eval "$(fritztools --bash-completion)"
```


## Examples:
You can either specify the FritzBox, your user and your password using the CLI arguments or by setting the following environment variables:
```
export FRITZ_IP_ADDRESS=192.168.178.1
export FRITZ_USERNAME=<your-fritz-username>
export FRITZ_PASSWORD=<your-fritz-password>
```
In the following we assume you're using the environment.

### Add or update a port forwarding for the host calling fritzportforward
We want to forward external port 80 to our internal port 80 of the host we're using to call the tool:
```
pipenv run ./fritzportforward -U -m 80:80 -n "HTTP-Server"
```
### List all port forwardings
When we list the port forwardings
```
pipenv run ./fritzportforward -l
```
we see something like:
```
Description          Protocol Dest. Host           Dest. IP             Mapping         Lease Duration    Status

[...]
HTTP-Server          TCP      <MY-HOST>            192.168.178.33       80->80          infinite          active
[...]

```

### Deactivate a port forwarding
```
pipenv run ./fritzportforward -D -m 80:80
```

### Reactivate a port forwarding
```
pipenv run ./fritzportforward -U -m 80:80
```

### Delete a port forwarding
Unfortunately current FritzBox releases don't support the deletion of port mapping entries.
