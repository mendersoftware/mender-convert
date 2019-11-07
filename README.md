[![Build Status](https://gitlab.com/Northern.tech/Mender/mender-convert/badges/next/pipeline.svg)](https://gitlab.com/Northern.tech/Mender/mender-convert/pipelines)

# mender-convert

Mender is an open source over-the-air (OTA) software updater for embedded Linux devices. Mender comprises a client running at the embedded device, as well as a server that manages deployments across many devices.

This repository contains mender-convert, which is used to convert pre-built disk images (Debian, Ubuntu, Raspbian, etc) to a Mender compatible image by restructuring partition table and injecting the necessary files.

For a full list of tested devices and images please visit [Mender Hub](https://hub.mender.io/c/board-integrations/debian-family). If your device and image combination is not listed as supported, this does not necessarily mean that it will not work, it probably just means that no one has tested and reported it back and usually only small tweaks are necessary to get this running on your device.

![Mender logo](https://github.com/mendersoftware/mender/raw/master/mender_logo.png)


## Getting started

To start using Mender, we recommend that you begin with the Getting started
section in [the Mender documentation](https://docs.mender.io/).

For more detailed information about `mender-convert` please visit the
[Debian family](https://docs.mender.io/artifacts/debian-family) section in
[the Mender documentation](https://docs.mender.io/).


### Prepare image and configuration

Download the raw Raspberry Pi disk image into a subdirectory input:

```bash
mkdir -p input
cd input
wget https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-06-24/2019-06-20-raspbian-buster-lite.zip
```

Extract the raw Raspberry Pi disk image:

```bash
unzip 2019-06-20-raspbian-buster-lite.zip && cd ..
```

Bootstrap the demo rootfs overlay that is configured to connect to
a Mender server with polling intervals set appropriately for
demonstration purposes.  There are three scripts here to support
the Mender demo server, the Mender production server, and Mender
Professional.

**NOTE!** Only run one of these three steps depending on the server
type you are implementing.

#### Using the [Mender demo server](https://docs.mender.io/getting-started/on-premise-installation/create-a-test-environment)
```
./scripts/bootstrap-rootfs-overlay-demo-server.sh \
    --output-dir ${PWD}/rootfs_overlay_demo \
    --server-ip 192.168.1.1
```

#### Using the [Mender production server](https://docs.mender.io/administration/production-installation)
```
./scripts/bootstrap-rootfs-overlay-production-server.sh \
    --output-dir ${PWD}/rootfs_overlay_demo \
    --server-url https://foobar.mender.io \
    [ --server-cert ~/server.crt ]
```

#### Using [Mender Professional](https://mender.io/products/mender-professional)
```
./scripts/bootstrap-rootfs-overlay-hosted-server.sh \
    --output-dir ${PWD}/rootfs_overlay_demo \
    --tenant-token "Paste token from Mender Professional"
```


### Docker environment for mender-convert

To make using mender-convert easier, a reference setup using a Docker
container is provided.

You need to [install Docker Engine](https://docs.docker.com/install) to use
this environment.


#### Build the mender-convert container image

Build a container with all required dependencies for `mender-convert`:

```bash
./docker-build
```

This will create a container image which you can use to run `mender-convert`
without polluting your host environment with the necessary dependencies.


#### Use the mender-convert container image

Run mender-convert from inside the container with your desired options, e.g.

```bash
MENDER_ARTIFACT_NAME=release-1 ./docker-mender-convert \
    --disk-image input/2019-04-08-raspbian-stretch-lite.img \
    --config configs/raspberrypi3_config \
    --overlay rootfs_overlay_demo/
```

Conversion will take 10-30 minutes, depending on image size and resources
available. You can watch `work/convert.log` for progress and diagnostics
information.

After it finishes, you can find your images in the `deploy` directory on your
host machine!

## Using mender-convert without Docker

In order to be able to manipulate and create filesystem and disk images,
mender-convert has a few dependencies, and their version and name vary between
Linux distributions. Here is an example of how to install the dependencies on a
Debian based distribution:

```
sudo apt install $(cat requirements-deb.txt)
```

Start the conversion process with:

```bash
MENDER_ARTIFACT_NAME=release-1 ./mender-convert \
    --disk-image input/2019-04-08-raspbian-stretch-lite.img \
    --config configs/raspberrypi3_config \
    --overlay rootfs_overlay_demo/
```

**NOTE!** You will be prompted to enter `sudo` password during the conversion
process. This is required to be able to loopback mount images and for modifying
them. Our recommendation is to use the provided Docker container, to run the
tool in a isolated environment (at least to some degree).


## Contributing

We welcome and ask for your contribution. If you would like to contribute to
Mender, please read our guide on how to best get started
[contributing code or documentation](https://github.com/mendersoftware/mender/blob/master/CONTRIBUTING.md).


## License

Mender is licensed under the Apache License, Version 2.0. See
[LICENSE](https://github.com/mendersoftware/mender-convert/blob/master/LICENSE)
for the full license text.


## Security disclosure

We take security very seriously. If you come across any issue regarding
security, please disclose the information by sending an email to
[security@mender.io](security@mender.io). Please do not create a new public
issue. We thank you in advance for your cooperation.


## Connect with us

* Join the [Mender Hub discussion forum](https://hub.mender.io)
* Follow us on [Twitter](https://twitter.com/mender_io). Please
  feel free to tweet us questions.
* Fork us on [Github](https://github.com/mendersoftware)
* Create an issue in the [bugtracker](https://tracker.mender.io/projects/MEN)
* Email us at [contact@mender.io](mailto:contact@mender.io)
* Connect to the [#mender IRC channel on Freenode](http://webchat.freenode.net/?channels=mender)


## Authors

Mender was created by the team at [Northern.tech AS](https://northern.tech),
with many contributions from the community. Thanks
[everyone](https://github.com/mendersoftware/mender/graphs/contributors)!

[Mender](https://mender.io) is sponsored by [Northern.tech AS](https://northern.tech).
