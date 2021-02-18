const jsdom = require("jsdom");
const { JSDOM } = jsdom;

// How to handle the different variables? Simply have the different runs output the new variable?

/////////////////////////////////
// BBB_DEBIAN_SDCARD_IMAGE_URL //
/////////////////////////////////

var beagleboard = {
    url: "https://debian.beagleboard.org/images",
    imageName: "bone-debian-10.3-iot-armhf-2020-04-06-4gb.img.xz",
    reg: "bone-debian-(?<version>[0-9]+\.[0-9]+)-iot-armhf-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{1,2})-4gb.img.xz$",
    DOMTransform: function(dom) {
        var document = dom.window.document;
        var table = document.getElementById("list");
        var rows = table.rows;
        var matches = [];
        for (var i=0; i< rows.length; i++) {
            var rowText = rows[i].firstChild.textContent;
            var regMatch = rowText.match(this.reg);
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
        if (matches[0].text !== this.imageName) {
            console.log("We've got a new release! \\o/");
        }
    }
}

console.log("Running BeagleBone check...")
JSDOM.fromURL(beagleboard.url, {}).then(dom => beagleboard.DOMTransform(dom));

///////////////////////////////
// BBB_DEBIAN_EMMC_IMAGE_URL //
///////////////////////////////

var beagleboardDebian = {
    url: "https://rcn-ee.com/rootfs/bb.org/testing",
    latestDate: "2021-01-11",
    reg: "[0-9]{4}-[0-9]{2}-[0-9]{1,2}/",
    DOMTransform: function(dom) {
        var document = dom.window.document;
        var table = document.getElementsByTagName("table");
        var rows = table[0].rows;
        var matches = [];
        for (var i=0; i< rows.length; i++) {
            try {
                if (rows[i].children.length != 5) {
                    continue;
                }
                var text = rows[i].children[1].textContent;
                var m = text.match(this.reg);
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
        if (matches[0] !== this.latestDate) {
            console.log("We've got a new release! \\o/");
            console.log(matches[0]);
            console.log("Old:");
            console.log(this.latestDate);
        }
    }
}

console.log("Running BeagleBoneDebian check...")
JSDOM.fromURL(beagleboardDebian.url, {}).then(dom => beagleboardDebian.DOMTransform(dom));


////////////////////////
// RASPBIAN_IMAGE_URL //
////////////////////////

var rpi = {
    url: "http://downloads.raspberrypi.org/raspbian_lite/images",
    imageName: "raspbian_lite-2019-09-30",
    reg: "raspbian_lite-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{1,2})/(?<updated>[0-9]{4}-[0-9]{2}-[0-9]{1,2}).*$",
    DOMTransform: function(dom) {
        var document = dom.window.document;
        var table = document.getElementsByTagName("table");
        var rows = table[0].rows;
        var matches = [];
        for (var i=0; i< rows.length; i++) {
            var rowText = rows[i].textContent;
            var regMatch = rowText.match(this.reg);
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
        if (matchOn !== this.imageName) {
            console.log("We've got a new release! \\o/");
            console.log(matchOn)
            console.log("Old match")
            console.log(this.imageName)
        }
    }
}


console.log("Running Raspbian image check...")
JSDOM.fromURL(rpi.url, {}).then(dom => rpi.DOMTransform(dom));


//////////////////////
// TINKER_IMAGE_URL //
//////////////////////

var tinkerboard = {
    url: "https://www.asus.com/us/Single-Board-Computer/Tinker-Board/",
    imageName: "http://dlcdnet.asus.com/pub/ASUS/mb/Linux/Tinker_Board_2GB/20170417-tinker-board-linaro-stretch-alip-v1.8.zip",
    reg: "http://dlcdnet.asus.com/pub/ASUS/mb/Linux/Tinker_Board_2GB/(?<date>[0-9]{8})-tinker-board-linaro-stretch-alip-v(?<version>[0-9]\.[0-9]).zip",
    DOMTransform: function(dom) {
    var document = dom.window.document;
    var section = document.getElementById("tinker-board-Download");
    var boards = section.getElementsByTagName("b")
    for (var i=0; i<boards.length; i++) {
        if (boards[i].textContent == "TinkerOS-Debian") {
            var newRef = boards[i].parentElement.href
            var regNewMatch = newRef.match(this.reg)
            var regOldMatch = this.imageName.match(this.reg)
            let vn = parseFloat(regNewMatch.groups.version)
            let vo = parseFloat(regOldMatch.groups.version)
            if (vn > vo) {
                console.log("A new version is release \\o/")
                console.log(newRef)
                break;
            } else if ( vn == vo ) {
                let dn = parseInt(regNewMatch.groups.date)
                let _do = parseInt(regOldMatch.groups.date)
                if (dn > _do) {
                    console.log("A newer version has been released \\o/")
                    console.log(newRef)
                    break
                }
            }
            break;
        }
    }
    }
}

console.log("Running the Tinkerboard check...")
JSDOM.fromURL(tinkerboard.url, {}).then(dom => tinkerboard.DOMTransform(dom));

/////////////////////////////////
// UBUNTU_SERVER_RPI_IMAGE_URL //
/////////////////////////////////

var ubuntuServer = {
    url: "http://cdimage.ubuntu.com/ubuntu/releases/",
    imageName: "18.04.5",
    reg: "(?<release>[0-9]{2})\.04(?<minor>.*)",
    DOMTransform: function(dom) {
        var document = dom.window.document;
        var refs = document.getElementsByTagName("a");
        var matches = []
        for (var i=0; i< refs.length; i++) {
            var textContent = refs[i].textContent
            var regMatch = textContent.match(this.reg)
            if (regMatch) {
                matches.push(regMatch)
            }
        }
        // Sort the accumulated matches
        matches.sort(function(a,b) {
            let al = parseInt(a.groups.release);
            let bl = parseInt(b.groups.release);
            if (al == bl) {
                return parseFloat(b.groups.minor) - parseFloat(a.groups.minor)
            }
            return bl - al;
        });
        var matchOn = matches[0].input
        if (matchOn !== this.imageName) {
            console.log("We've got a new release! \\o/");
            console.log(matchOn)
            console.log("Old match")
            console.log(this.imageName)
        }
    }
}

console.log("Running ubuntu check...")
JSDOM.fromURL(ubuntuServer.url, {}).then(dom => ubuntuServer.DOMTransform(dom));
