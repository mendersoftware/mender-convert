[![Build Status](https://gitlab.com/Northern.tech/Mender/mender-convert/badges/next/pipeline.svg)](https://gitlab.com/Northern.tech/Mender/mender-convert/pipelines)

# mender-convert

Mender is an open source over-the-air (OTA) software updater for embedded Linux
devices. Mender comprises a client running at the embedded device, as well as a
server that manages deployments across many devices.

This repository contains mender-convert, which is used to convert pre-built disk
images (Debian, Ubuntu, Raspbian, etc) to a Mender compatible image by
restructuring partition table and injecting the necessary files.

For a full list of tested devices and images please visit [Mender
Hub](https://hub.mender.io/c/board-integrations/debian-family). If your device
and image combination is not listed as supported, this does not necessarily mean
that it will not work, it probably just means that no one has tested and
reported it back and usually only small tweaks are necessary to get this running
on your device.

-------------------------------------------------------------------------------

![Mender logo](https://github.com/mendersoftware/mender/raw/master/mender_logo.png)

## Requisites

`mender-convert` is supported on the following development platform(s):

	- Ubuntu 18.04 x86, 64bit

Other platforms may work, but are not under active testing. Patches to add additional
platforms or fix compatibility issues are welcome.

The storage used during the process, specifically the work directories (usually below the clone of
`mender-convert`) and the output directory should be located on local, Unix-style filesystem.
Using network storage or emulated filesystems might cause permission or owner issues.


## Getting started

To start using Mender, we recommend that you begin with the Getting started
section in [the Mender documentation](https://docs.mender.io/).

For more detailed information about `mender-convert` please visit the
[Debian family](https://docs.mender.io/artifacts/debian-family) section in
[the Mender documentation](https://docs.mender.io/).

## Included configurations

### Core configurations

These configurations are officially supported.

| Configuration | Supported OS / hardware |
| :------------ | :---------------------- |
| generic_x86-64_config | Generic x86, 64bit distribution *use this as a starting point only!*  |
| raspberrypi0w_config | RaspberryPi 0w, Raspbian 32bit |
| raspberrypi3_config | RaspberryPi 3, Raspbian 32bit |
| raspberrypi4_config | RaspberryPi 4, Raspbian 32bit |
| raspberrypi4_ubuntu_config | RaspberryPi 4, Ubuntu 32bit |

### Contributed configurations

These configurations have been submitted by community contributors.

| Configuration | Supported OS / hardware |
| :------------ | :---------------------- |
| comfile_pi_config | Comfile Pi, Raspbian 32bit |
| rockpro64_emmc_config | RockPro64, Debian 32bit on internal eMMC storage |
| rockpro64_sd_config | RockPro64, Debian 32bit on external SD card storage |

## Example usage: Raspberry Pi 3, Raspbian 32bit

### Prepare image and configuration

The following steps give a quick start using Raspbian. For a more detailed guide,
especially concerning version compatibilities, please visit [the the corresponding thread](https://hub.mender.io/t/raspberry-pi-3-model-b-b-raspbian/140) on the Mender Hub.

Download the raw Raspberry Pi disk image into a subdirectory input:

```bash
mkdir -p input
cd input
wget https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-06-24/2019-06-20-raspbian-buster-lite.zip
```

Extract the raw Raspberry Pi disk image:

```bash
unzip 2019-06-20-raspbian-buster-lite.zip
INPUT_DISK_IMAGE=$(ls *raspbian-buster*.img)
cd ..
```

Bootstrap the demo rootfs overlay that is configured to connect to
a Mender server with polling intervals set appropriately for
demonstration purposes.  There are three scripts here to support
the Mender demo server, the Mender production server, and Mender
Professional.

**NOTE!** Only run one of these three steps depending on the server
type you are implementing.

#### Using [hosted Mender](https://mender.io/pricing/plans)
```bash
./scripts/bootstrap-rootfs-overlay-hosted-server.sh \
    --output-dir ${PWD}/input/rootfs_overlay_demo \
    --tenant-token "Paste token from Mender Professional"
```

#### Using the [Mender demo server](https://docs.mender.io/development/server-installation/evaluation-with-docker-compose)
```bash
./scripts/bootstrap-rootfs-overlay-demo-server.sh \
    --output-dir ${PWD}/input/rootfs_overlay_demo \
    --server-ip 192.168.1.1
```

#### Using the [Mender on-premise server](https://docs.mender.io/development/server-installation)
```bash
./scripts/bootstrap-rootfs-overlay-production-server.sh \
    --output-dir ${PWD}/input/rootfs_overlay_demo \
    --server-url https://foobar.mender.io \
    [ --server-cert ~/server.crt ]
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

This will create a container image with the name `mender-convert` which you can
use to run `mender-convert` without polluting your host environment with the
necessary dependencies.


#### Use the mender-convert container image

Run mender-convert from inside the container with your desired options, e.g.

```bash
mkdir -p input/image
cp $PATH_TO_DISK_IMAGE/$INPUT_DISK_IMAGE input/image

mkdir -p input/config
cp $PATH_TO_MY_OWN_CONFIG/$CUSTOM_CONFIG input/config

MENDER_ARTIFACT_NAME=release-1 ./docker-mender-convert \
   --disk-image input/image/$INPUT_DISK_IMAGE \
   --config configs/raspberrypi3_config \
   --config input/config/$CUSTOM_CONFIG \
   --overlay input/rootfs_overlay_demo
```

The container will use the `work/` directory as a temporary area to unpack and
customize the image's content. You can customize the work directory path
by setting the `WORK_DIRECTORY` env variable. To reduce the time required to
perform the conversion, you can use tempfs or ramfs mount points.

Conversion will take 10-30 minutes, depending on image size and resources
available. You can watch `log/convert.log.XXXXX` for progress and diagnostics
information. The exact log file path is printed before the conversion starts.

After it finishes, you can find your images in the `deploy` directory on your
host machine!

#### Troubleshooting

A continuously expanded list of possible problems and how to address those is
maintained in the [Mender documentation](https://docs.mender.io/troubleshoot/mender-client)

## Using mender-convert without Docker

In order to be able to manipulate and create filesystem and disk images,
mender-convert has a few dependencies, and their version and name vary between
Linux distributions. Here is an example of how to install the dependencies on a
Debian based distribution:

```bash
sudo apt install $(cat requirements-deb.txt)
```

Start the conversion process with:

```bash
MENDER_ARTIFACT_NAME=release-1 ./mender-convert \
   --disk-image input/$INPUT_DISK_IMAGE \
   --config configs/raspberrypi3_config \
   --overlay input/rootfs_overlay_demo
```

**NOTE!** You will be prompted to enter `sudo` password during the conversion
process. This is required to be able to loopback mount images and for modifying
them. Our recommendation is to use the provided Docker container, to run the
tool in an isolated environment.

-------------------------------------------------------------------------------

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
* Create an issue in the [bugtracker](https://northerntech.atlassian.net/projects/MEN)
* Email us at [contact@mender.io](mailto:contact@mender.io)
* Connect to the [#mender IRC channel on Libera](https://web.libera.chat/?#mender)


## Authors

Mender was created by the team at [Northern.tech AS](https://northern.tech),
with many contributions from the community. Thanks
[everyone](https://github.com/mendersoftware/mender/graphs/contributors)!

[Mender](https://mender.io) is sponsored by [Northern.tech AS](https://northern.tech).
