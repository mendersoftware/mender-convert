# Run tests

Run the following commands to install test dependencies (assumes that all mender-convert dependencies are already installed):

    sudo apt-get update e2fsprogs=1.44.1-1
    sudo apt-get -qy --force-yes install python-pip
    sudo pip2 install pytest --upgrade
    sudo pip2 install pytest-xdist --upgrade
    sudo pip2 install pytest-html --upgrade

Run tests:

    ./scripts/run-tests.sh
