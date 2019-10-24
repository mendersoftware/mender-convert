[![Build Status](https://travis-ci.com/mendersoftware/mender-convert.svg?branch=master)](https://travis-ci.com/mendersoftware/mender-convert)

mender-convert
==============

Mender is an open source over-the-air (OTA) software updater for embedded Linux devices. Mender comprises a client running at the embedded device, as well as a server that manages deployments across many devices.

This repository contains mender-convert, which is used to convert pre-built disk images (Debian, Ubuntu, Raspbian, etc) to a Mender compatible
image by restructuring partition table and injecting the necessary files.

Currently official Raspberry Pi 3 and BeagleBone Black images are supported and this will be extended.

![Mender logo](https://github.com/mendersoftware/mender/raw/master/mender_logo.png)

## Getting started

To start using Mender, we recommend that you begin with the Getting started
section in [the Mender documentation](https://docs.mender.io/).


## Docker environment for mender-convert

In order to correctly set up partitions and bootloaders, mender-convert has many dependencies,
and their version and name vary between Linux distributions.

To make using mender-convert easier, a reference setup using a Ubuntu 18.04 Docker container
is provided.

You need to [install Docker Engine](https://docs.docker.com/install) to use this environment.


### Build the mender-convert container image

To build a container based on Ubuntu 18.04 with all required dependencies for mender-convert,
copy this directory to your workstation and change the current directory to it.

Then run

```bash
./docker-build
```

This will create a container image you can use to run mender-convert.


### Use the mender-convert container image

Create a directory `input` under the directory where you copied these files (`docker-build`, `docker-mender-convert`, etc.):

```bash
mkdir input
```

Then put your raw disk image into `input/`, e.g.

```bash
mv ~/Downloads/2018-11-13-raspbian-stretch.img input/2018-11-13-raspbian-stretch.img
```

You can run mender-convert from inside the container with your desired options, e.g.


```bash
DEVICE_TYPE="raspberrypi3"
RAW_DISK_IMAGE="input/2018-11-13-raspbian-stretch.img"

ARTIFACT_NAME="2018-11-13-raspbian-stretch"
MENDER_DISK_IMAGE="2018-11-13-raspbian-stretch.sdimg"
TENANT_TOKEN="<INSERT-TOKEN-FROM Hosted Mender>"

./docker-mender-convert from-raw-disk-image                      \
            --raw-disk-image $RAW_DISK_IMAGE                     \
            --mender-disk-image $MENDER_DISK_IMAGE               \
            --device-type $DEVICE_TYPE                           \
            --artifact-name $ARTIFACT_NAME                       \
            --bootloader-toolchain arm-buildroot-linux-gnueabihf \
            --server-url "https://hosted.mender.io"              \
            --tenant-token $TENANT_TOKEN
```

By default conversion in containter uses GCC 7.3.0 bootlin toolchain tuned for
ARMv6 architecture (especially for ARM1176(F)-S single-core processor).
The aim of that is to provide a support for the Raspberry Pi Zero W development board.

ARMv7 is backward compatible with ARMv6, so binaries compiled for ARMv6 should also work on ARMv7.

Note that the default Mender client is the latest stable and cross-compiled for generic ARM boards,
which should work well in most cases. If you would like to use a different Mender client,
place it in `input/` and adjust the `--mender-client` argument.

Conversion will take 10-15 minutes, depending on your storage and resources available.
You can watch `output/build.log` for progress and diagnostics information.

After it finishes, you can find your images in the `output` directory on your host machine!


### Known issues
* An issue for `Raspberry Pi Zero W` has been spotted with the `mender-convert` tool version 1.1.0.
  After an initial boot, having last partition resized to the end of the SD card, the correct device
  tree cannot be found. As a result the boot cannot succeed.
  For more information and current status, see [issue tracker](https://tracker.mender.io/browse/MEN-2436).
* If building U-boot fails with:
```
     D	scripts/Kconfig
     input in flex scanner failed
     ....
     include/linux/kconfig.h:4:32: fatal error: generated/autoconf.h: No such file or directory
     #include <generated/autoconf.h>
```
you might be using a case-sensitive filesystem which is not supported. Case-sensitive filesystems are typically used on OSX (Mac) and Windows but you can also run in to this on Linux if running on a NTFS formatted partition.

For details see this [discussion](https://hub.mender.io/t/raspberry-pi-3-model-b-b-raspbian/140/10)


## Contributing

We welcome and ask for your contribution. If you would like to contribute to Mender, please read our guide on how to best get started [contributing code or documentation](https://github.com/mendersoftware/mender/blob/master/CONTRIBUTING.md).

## License

Mender is licensed under the Apache License, Version 2.0. See [LICENSE](https://github.com/mendersoftware/mender-crossbuild/blob/master/LICENSE) for the full license text.

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
