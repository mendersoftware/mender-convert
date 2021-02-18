const jsdom = require("jsdom");
const { JSDOM } = jsdom;

const url = "http://cdimage.ubuntu.com/ubuntu/releases/"
const imageName = "18.04.5"

var reg = "(?<release>[0-9]{2})\.04(?<minor>.*)"

JSDOM.fromURL(url, {}).then(dom => {
    var document = dom.window.document;
    var refs = document.getElementsByTagName("a");
    var matches = []
    for (var i=0; i< refs.length; i++) {
        var textContent = refs[i].textContent
        var regMatch = textContent.match(reg)
        if (regMatch) {
            matches.push(regMatch)
        }
    }
    // Sort the accumulated matches
    matches.sort(function(a,b) {
        let al = parseInt(a.groups.release);
        let bl = parseInt(b.groups.release);
        console.log(b)
        console.log(bl)
        if (al == bl) {
            console.log(parseFloat(b.groups.minor))
            return parseFloat(b.groups.minor) - parseFloat(a.groups.minor)
        }
        return bl - al;
    });
    var matchOn = matches[0].input
    if (matchOn !== imageName) {
        console.log("We've got a new release! \\o/");
        console.log(matchOn)
        console.log("Old match")
        console.log(imageName)
    }
});
