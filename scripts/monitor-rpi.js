const jsdom = require("jsdom");
const { JSDOM } = jsdom;

const url = "http://downloads.raspberrypi.org/raspbian_lite/images"
const imageName = "bone-debian-10.3-iot-armhf-2020-04-06-4gb.img.xz"

var reg = "bone-debian-(?<version>[0-9]+\.[0-9]+)-iot-armhf-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{1,2})-4gb.img.xz$"
var arr = imageName.match(reg);

JSDOM.fromURL(url, {}).then(dom => {
    console.log(dom.serialize());
    var document = dom.window.document;
    console.log(document.getElementsByTagName("list"));
    var table = document.getElementsByTagName("list");
    var rows = table[0].rows;
    var matches = [];
    for (var i=0; i< rows.length; i++) {
        var rowText = rows[i].textContent;
        // console.log(rowText);
        // var regMatch = rowText.match(reg);
        // if (regMatch) {
        //     console.log(rowText);
        //     matches.push({
        //         text: rowText,
        //         version: regMatch.groups.version,
        //         date: regMatch.groups.date,
        //     });
        // }
    }
    // Sort the accumulated matches
    // matches.sort(function(a,b) {
    //     let al = parseFloat(a.version);
    //     let bl = parseFloat(b.version);
    //     if (al == bl) {
    //         let ad = Date.parse(a.date);
    //         let bd = Date.parse(b.date);
    //         return bd - ad;
    //     }
    //     return parseFloat(b.version) - parseFloat(a.version);
    // });
    // if (matches[0].text !== imageName) {
    //     console.log("We've got a new release! \\o/");
    // }
});
