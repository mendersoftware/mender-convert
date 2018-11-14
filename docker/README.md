Docker environment for mender-convert
=====================================

In order to correctly set up partitions and bootloaders, mender-convert has many dependencies,
and their version and name vary between Linux distributions.

To make using mender-convert easier, a reference setup using a Ubuntu 18.04 Docker container
is provided.

You need to [install Docker Engine CE](https://docs.docker.com/install) to use this environment.


## Build the mender-convert container image

To build a container based on Ubuntu 18.04 with all required dependencies for mender-convert,
copy this directory to your workstation and change the current directory to it.

Then run

```bash
./build.sh
```

This will create a container image you can use to run mender-convert.


## Use the mender-convert container image

Create a directory `input` under the directory where you copied these files (`build.sh`, `run.sh`, etc.):

```bash
mkdir input
```

Put your raw disk image into `input`, e.g. `input/2018-10-09-raspbian-stretch.img`.
Then put a Mender client binary compiled for your device into `input/mender-1.6.0-arm-linux-gnueabihf-gcc`.
See [the Mender documentation on how to cross-compile the Mender client for your device](https://docs.mender.io/development/client-configuration/cross-compiling).

After you have built or pulled the mender-convert container image,
you can run it with

```bash
./run.sh
```

This will drop you into a shell environment (interactive mode).
Change to the mender-convert directory:

```bash
cd /mender-convert
```

You can now run mender-convert with your desired options, e.g.

```bash
DEVICE_TYPE="raspberrypi3"
RAW_DISK_IMAGE="input/2018-10-09-raspbian-stretch.img"
MENDER_CLIENT="input/mender-1.6.0-arm-linux-gnueabihf-gcc"

ARTIFACT_NAME="2018-10-09-raspbian-stretch"
MENDER_DISK_IMAGE="2018-10-09-raspbian-stretch.sdimg"
TENANT_TOKEN="<INSERT-TOKEN-FROM Hosted Mender>"

./mender-convert from-raw-disk-image                        \
            --raw-disk-image $RAW_DISK_IMAGE                \
            --mender-disk-image $MENDER_DISK_IMAGE          \
            --device-type $DEVICE_TYPE                      \
            --mender-client $MENDER_CLIENT                  \
            --artifact-name $ARTIFACT_NAME                  \
            --bootloader-toolchain arm-linux-gnueabihf      \
            --server-url "https://hosted.mender.io"         \
            --tenant-token $TENANT_TOKEN
```

Conversion will take 10-15 minutes, depending on your storage and resources available.
You can watch `output/build.log` for progress and diagnostics information.

After it finishes, you can find your images in the `output` directory on your host machine!


## Known issues
* BeagleBone images might not convert properly using this docker envirnoment due to permission issues: `mount: /mender-convert/output/embedded/rootfs: WARNING: device write-protected, mounted read-only.`