# Run tests

Commands must be run from the root directory of `mender-convert`.

The tests utilize `docker-mender-convert` to run the conversion.
You can specify a prebuilt image or build the image yourself using:
```bash
./docker-build
```

Run tests:
```bash
./scripts/test/run-tests.sh --config <extra_config_file> --only <device_type> --prebuilt-image <device_type> <image_name> -- <pytest-options>
```
