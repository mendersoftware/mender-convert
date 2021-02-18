const jsdom = require("jsdom");
const { JSDOM } = jsdom;

const url = "https://debian.beagleboard.org/images"
const imageName = "bone-debian-10.3-iot-armhf-2020-04-06-4gb.img.xz"
var reg = "bone-debian-(?<version>[0-9]+\.[0-9]+)-iot-armhf-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{1,2})-4gb.img.xz$"

// The bone-debian setup has two parts which needs comparing:
// * The release-version: i.e., 10.3
// * The date: i.e., 2020-04-06

JSDOM.fromURL("https://debian.beagleboard.org/images", {}).then(dom => {
    var document = dom.window.document;
    var table = document.getElementById("list");
    var rows = table.rows;
    var matches = [];
    for (var i=0; i< rows.length; i++) {
        var rowText = rows[i].firstChild.textContent;
        var regMatch = rowText.match(reg);
        if (regMatch) {
            matches.push({
                text: rowText,
                version: regMatch.groups.version,
                date: regMatch.groups.date,
            });
        }
    }
    // Sort the accumulated matches
    matches.sort(function(a,b) {
        let al = parseFloat(a.version);
        let bl = parseFloat(b.version);
        if (al == bl) {
            let ad = Date.parse(a.date);
            let bd = Date.parse(b.date);
            return bd - ad;
        }
        return parseFloat(b.version) - parseFloat(a.version);
    });
    if (matches[0].text !== imageName) {
        console.log("We've got a new release! \\o/");
    }
});
