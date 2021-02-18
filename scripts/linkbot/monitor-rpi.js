const jsdom = require("jsdom");
const { JSDOM } = jsdom;
const fs = require('fs')
const { updateURLLink } = require('./common');

const target = "RASPBIAN_IMAGE_URL"

// Read the input file, and parse the variable input
try {
    const data = fs.readFileSync('../test/run-tests.sh', 'utf8')
          .split('\n')
          .filter(line => line.match(`${target}=.*`))
    var line = data[0]
    console.log(line)
    var reg = "raspbian_lite-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{1,2})/(?<updated>[0-9]{4}-[0-9]{2}-[0-9]{1,2}).*$"
    var m = line.match(".*=\"(?<url>[a-zA-Z-://\._]*)(?<imageName>raspbian_lite-[0-9]{4}-[0-9]{2}-[0-9]{1,2})/(?<updated>[0-9]{4}-[0-9]{2}-[0-9]{1,2}).*$")
    console.log(m)
    var url = m.groups.url
    var imageName = m.groups.imageName
    var updated = m.groups.updated
} catch (err) {
    console.error(err)
    process.exit(1)
}

JSDOM.fromURL(url, {}).then(dom => {
    var document = dom.window.document;
    var table = document.getElementsByTagName("table");
    var rows = table[0].rows;
    var matches = [];
    for (var i=0; i< rows.length; i++) {
        var rowText = rows[i].textContent;
        var regMatch = rowText.match(reg);
        if (regMatch) {
            matches.push(regMatch);
        }
    }
    // Sort the accumulated matches
    matches.sort(function(a,b) {
        let al = Date.parse(a.groups.date);
        let bl = Date.parse(b.groups.date);
        if (al == bl) {
            let ad = Date.parse(a.groups.updated);
            let bd = Date.parse(b.groups.updated);
            return bd - ad;
        }
        return bl - al;
    });
    var matchOn = matches[0].input.split("/")[0]
    if (matchOn !== imageName) {
        console.error("We've got a new release! \\o/");
        updateURLLink(`${target}=\"${url}${matches[0].input.split(" ")[0]}-raspbian-buster-lite.zip\"`, target)
    }
});
