const jsdom = require("jsdom");
const { JSDOM } = jsdom;
const bent = require('bent')
const getJSON = bent('json')
const fs = require('fs')
const { updateURLLink } = require('./common');

const target = "TINKER_IMAGE_URL"
const url = "https://tinker-board.asus.com/download-list.html?product=tinker-board"
let versionRegexp = "[vV](?<major>[0-9]{1,2}\.(?<minor>[0-9]{1,2})\.(?<patch>[0-9]{1,2}))"
const reg = ".*[Vv](?<major>[0-9]{1,2})\.(?<minor>[0-9]{1,2})\.(?<patch>[0-9]{1,2})?.*"

// Read the input file, and parse the variable input
try {
    const data = fs.readFileSync('../test/run-tests.sh', 'utf8')
          .split('\n')
          .filter(line => line.match(`${target}=.*`))
    var line = data[0]
    var m = line.match(`.*=\"${reg}`)
    console.log(m)
    var major = m.groups.major
    var minor = m.groups.minor
    var patch = m.groups.patch || 0
} catch (err) {
    console.error(err)
    process.exit(1)
}

let obj =  getJSON("https://www.asus.com/support/api/product.asmx/GetPDDrivers?cpu=&osid=8&website=global&pdhashedid=xOd5XdS4L5c6tt1O&model=Tinker%20Board%20S").then(result => {
    result.Result.Obj[0].Files.push({
        Title: "TinkerOS_Debian",
        Version: `V${major}.${minor}.${patch}`,
    })
    let matches = result.Result.Obj[0].Files.filter(obj => obj.Title.match("TinkerOS_Debian"))
        .sort((a,b) => {
            let matchA = a.Version.match(versionRegexp)
            let matchB = b.Version.match(versionRegexp)
            if (matchA && matchB) {
                return parseInt(matchB.major) - parseInt(matchA.major) ||
                    parseInt(matchB.minor) - parseInt(matchA.minor) ||
                    parseInt(matchB.patch) - parseInt(matchA.patch)
            }
        })
    console.log("matches")
    console.log(matches)

    // New version
    if (matches[0].DownloadUrl) {
        console.log(`${target}=${matches[0].DownloadUrl.Global}`)
        updateURLLink(`${target}=\"${matches[0].DownloadUrl.Global}\"`, target)
    }
})
