const jsdom = require("jsdom");
const { JSDOM } = jsdom;

const url = "https://www.asus.com/us/Single-Board-Computer/Tinker-Board/"
const imageName = "http://dlcdnet.asus.com/pub/ASUS/mb/Linux/Tinker_Board_2GB/20170417-tinker-board-linaro-stretch-alip-v1.8.zip"
const reg = "http://dlcdnet.asus.com/pub/ASUS/mb/Linux/Tinker_Board_2GB/(?<date>[0-9]{8})-tinker-board-linaro-stretch-alip-v(?<version>[0-9]\.[0-9]).zip"

JSDOM.fromURL(url, {}).then(dom => {
    var document = dom.window.document;
    var section = document.getElementById("tinker-board-Download");
    var boards = section.getElementsByTagName("b")
    for (var i=0; i<boards.length; i++) {
        if (boards[i].textContent == "TinkerOS-Debian") {
            var newRef = boards[i].parentElement.href
            var regNewMatch = newRef.match(reg)
            var regOldMatch = imageName.match(reg)
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
});
