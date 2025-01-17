## EVM state test tool

The `evmstate` tool to execute state test.

### Build instructions

There are few options to build `evmstate` tool like any other nimbus tools.

1. Use nimble to install dependencies and your system Nim compiler(version <= 1.6.0).
    ```
    $> nimble install -y --depsOnly
    $> nim c -d:release -d:chronicles_enabled=off tools/evmstate/evmstate
    $> nim c -r -d:release tools/evmstate/evmstate_test
    ```
2. Use nimbus shipped Nim compiler and dependencies.
    ```
    $> make update
    $> ./env.sh nim c -d:release -d:chronicles_enabled=off tools/evmstate/evmstate
    $> ./env.sh nim c -r -d:release tools/evmstate/evmstate_test
    ```
3. Use nimbus makefile.
    ```
    $> make update
    $> make evmstate
    $> make evmstate_test
    ```

### Command line params

Available command line params
```
Usage:

evmstate [OPTIONS]... <inputFile>

 <inputFile>         json file contains state test data.

The following options are available:

 --dump              dumps the state after the run [=false].
 --json              output trace logs in machine readable format (json) [=false].
 --debug             output full trace logs [=false].
 --nomemory          disable memory output [=true].
 --nostack           disable stack output [=false].
 --nostorage         disable storage output [=false].
 --noreturndata      enable return data output [=true].
 --verbosity         sets the verbosity level [=0].

```
