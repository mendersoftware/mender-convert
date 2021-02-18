const jsdom = require("jsdom");
const { JSDOM } = jsdom;

const url = "http://downloads.raspberrypi.org/raspbian_lite/images"
const imageName = "raspbian_lite-2019-09-30"
const reg = "raspbian_lite-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{1,2})/(?<updated>[0-9]{4}-[0-9]{2}-[0-9]{1,2}).*$"

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
        console.log("We've got a new release! \\o/");
        console.log(matchOn)
        console.log("Old match")
        console.log(imageName)
    }
});
