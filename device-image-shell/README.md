Device Image Shell
==================

This directory contains a tool that takes the root file system of your device as input and emulates a shell session on your device.
Any commands you run (e.g. apt update, apt upgrade) will behave as if you were logged into your actual device!

The purpose of the tool is to create a new root file system image and Mender Artifact that can be deployed to a fleet of devices in the field.


## Docker environment

To ensure dependencies are correctly set up and it is portable, a docker environment is used.

You need to [install Docker Engine](https://docs.docker.com/install) to use this tool.


### Build the device-image-shell container image

To build a container based on Ubuntu 18.04 with the required dependencies, copy this directory to your workstation and change the current directory to it.

Then run

```bash
./docker-build
```

This will create a container image `device-image-shell`.


### Use the device-image-shell container image

The also assumes your device is based on the ARM architecture, which is the most common (e.g. Raspberry Pi, BeagleBoard, etc.).

You need a root file system image (usually with .ext4 extension) for your device as a starting point, such as one output by [mender-convert](https://github.com/mendersoftware/mender-convert). Make sure to have `qemu-user-static` installed on a host machine.

You can now enter a shell in your device root file system image by running `docker-device-image-shell` with the desired arguments:

1. path to your existing root file system image
2. desired name for the generated Mender Artifact
3. device type, which Mender uses to ensure compatibility between devices and software

For example, if you are using a Raspberry Pi 3, you can run:

```bash
./docker-device-image-shell ../output/2018-11-13-raspbian-stretch-lite.ext4 2018-11-13-raspbian-stretch-lite-aptupgrade raspberrypi3
```

You should now see a shell prompt. You are in an emulated environment, so any commands run here will behave as if you ran them on your device! In addition, any changes you make will be preserved in the output root file system image and Mender Artifact.

For example, to update to the latest packages run:

```bash
apt update
apt upgrade
```

When you are done, press `Ctrl+D` or run the `exit` command. Generating the Mender Artifact will take a few more minutes, depending on the size of the input image and resources available on your workstation.

After it finishes you can find your new `.ext4` and `.mender` files in the `output/` directory. For devices where Mender is installed, you can use the Mender Artifact (`.mender` file) to deploy the changes you made in the shell to all your devices!


### Use caution

Please note that since this tool is using an emulated environment (based on `qemu`) and you are not properly logged in to your device, some things may not work as expected. Look for any relevant errors in  commands you run and make sure to test your changes before deploying to production devices!
