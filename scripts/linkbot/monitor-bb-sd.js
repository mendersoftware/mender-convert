const jsdom = require("jsdom");
const { JSDOM } = jsdom;
const fs = require('fs')
const { updateURLLink } = require('./common');

const target = "BBB_DEBIAN_SDCARD_IMAGE_URL"

var reg = "bone-debian-(?<version>[0-9]+\.[0-9]+)-iot-armhf-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{1,2})-4gb.img.xz$"

// Read the input file, and parse the variable input
try {
    const data = fs.readFileSync('../test/run-tests.sh', 'utf8')
          .split('\n')
          .filter(line => line.match(`${target}=.*`))
    var line = data[0]
    var m = line.match(".*=\"(?<url>[a-zA-Z-://\._]*)(?<imageName>bone-debian-(?<version>[0-9]+\.[0-9]+)-iot-armhf-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{1,2})-4gb.img.xz)")
    var url = m.groups.url
    var currentImageName = m.groups.imageName
} catch (err) {
    console.error(err)
    process.exit(1)
}

JSDOM.fromURL(url, {}).then(dom => {
    var document = dom.window.document;
    var table = document.getElementById("list");
    var rows = table.rows;
    var matches = Array.from(rows)
        .filter(row => row.firstChild.textContent.match(reg))
        .reduce((acc, element) => {
            var regMatch = element.firstChild.textContent.match(reg)
            acc.push({
                text: element.firstChild.textContent,
                version: regMatch.groups.version,
                date: regMatch.groups.date,
            })
            return acc
        }, [])
        .sort((a,b) => {
            // The bone-debian setup has two parts which needs comparing:
            // * The release-version: i.e., 10.3
            // * The date: i.e., 2020-04-06
            return parseFloat(b.version) - parseFloat(a.version) || Date.parse(b.date) - Date.parse(a.date)
        })
    if (matches[0].text !== currentImageName) {
        console.error("We've got a new release! \\o/");
        updateURLLink(`${target}=\"${url}/${matches[0].text}\"`)
    }
});
