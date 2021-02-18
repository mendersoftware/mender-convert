const jsdom = require("jsdom");
const { JSDOM } = jsdom;
const fs = require('fs')
const { updateURLLink } = require('./common');

const url = "http://cdimage.ubuntu.com/ubuntu/releases/"
const reg = ".*(?<release>[0-9]{2})\.04\.?(?<minor>[0-9]{1})?.*"

// Read the input file, and parse the variable input
try {
    const data = fs.readFileSync('../test/run-tests.sh', 'utf8')
          .split('\n')
          .filter(line => line.match("UBUNTU_SERVER_RPI_IMAGE_URL=.*"))
    var line = data[0]
    var m = line.match(`.*=\"${reg}\"`)
    var imageName = m.groups.release
    var minor = m.groups.minor || 0
} catch (err) {
    console.error(err)
    process.exit(1)
}

JSDOM.fromURL(url, {}).then(dom => {
    var document = dom.window.document;
    var refs = document.getElementsByTagName("a");
    var matches = Array.from(refs)
        .filter(ref => ref.textContent.match(reg))
        .reduce((acc, ref) => {
            acc.push(ref.textContent.match(reg))
            return acc
        }, [])
        .sort((a,b) => {
            return parseInt(b.groups.release) - parseInt(a.groups.release) || parseFloat(b.groups.minor) - parseFloat(a.groups.minor)
        })
    var matchOn = matches[0].input
    if (matchOn !== imageName) {
        console.log("We've got a new release! \\o/");
        var newLine = ""
        if (matches[0].groups.minor) {
            newLine = `UBUNTU_SERVER_RPI_IMAGE_URL=\"${url}${matches[0].groups.release}.04.${matches[0].groups.minor}/release/ubuntu-${matches[0].groups.release}.04.${matches[0].groups.minor}-preinstalled-server-armhf+raspi.img.xz\"`
        } else {
            newLine = `UBUNTU_SERVER_RPI_IMAGE_URL=\"${url}${matches[0].groups.release}.04/release/ubuntu-${matches[0].groups.release}.04-preinstalled-server-armhf+raspi.img.xz\"`
        }
        updateURLLink(newLine)
    }
});
