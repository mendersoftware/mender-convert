const jsdom = require("jsdom");
const { JSDOM } = jsdom;

const url = "https://rcn-ee.com/rootfs/bb.org/testing"
const latestDate = "2021-01-11"
const reg = "[0-9]{4}-[0-9]{2}-[0-9]{1,2}/"

JSDOM.fromURL(url, {}).then(dom => {
    var document = dom.window.document;
    var table = document.getElementsByTagName("table");
    var rows = table[0].rows;
    var matches = [];
    for (var i=0; i< rows.length; i++) {
        try {
            var text = rows[i].children[1].textContent;
            var m = text.match(reg);
            if (m) {
                matches.push(text);
            }
        } catch(error) {
            console.log(error);
        }
    }
    // Sort the accumulated matches
    matches.sort(function(a,b) {
        return Date.parse(b) - Date.parse(a);
    });
    if (matches[0] !== latestDate) {
        console.log("We've got a new release! \\o/");
        console.log(matches[0]);
        console.log("Old:");
        console.log(latestDate);
    }
});
