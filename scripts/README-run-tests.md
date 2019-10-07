# Run tests

The tests utilize the provided Docker container in this repository and conversion
is done using the `docker-mender-convert` command. For this reason we first need
to build the container (commands must be run from the root directory of
`mender-convert`):

```bash
./docker-build
```

Run tests:

```bash
./scripts/run-tests.sh
```
