const jsdom = require("jsdom");
const { JSDOM } = jsdom;

const fs = require('fs')


// Read the input file, and parse the variable input
try {
    const data = fs.readFileSync('test/run-tests.sh', 'utf8')
          .split('\n')
          .filter(line => line.match("BBB_DEBIAN_EMMC_IMAGE_URL=.*"))
    console.log("Data:")
    console.log(data[0])
    var line = data[0]
    var m = line.match(".*=\"(?<url>[a-zA-Z-://\.]*)(?<latestDate>[0-9]{4}-[0-9]{2}-[0-9]{1,2}/).*")
    console.log(m)
    console.log(m.groups.url)
    console.log(m.groups.latestDate)
    // var url = m.groups.url
    var url = m.groups.url
    var latestDate = m.groups.latestDate
} catch (err) {
    console.error(err)
    process.exit(1)
}

const reg = "[0-9]{4}-[0-9]{2}-[0-9]{1,2}/"

async function getNewBoneDebian(url) {
    var ret = "";
    await JSDOM.fromURL(url, {}).then(dom => {
        var document = dom.window.document;
        var refs = document.getElementsByTagName("a");
        for (var i=0; i< refs.length; i++) {
            try {
                var text = refs[i].textContent;
                var m = text.match("bone-debian.*\.img\.xz$");
                if (m) {
                    console.log("\\o/");
                    ret = `BBB_DEBIAN_EMMC_IMAGE_URL=${url}/${m.input}`;
                }
            } catch(error) {
                console.log(error);
            }
        }
    });
    return ret;
}

JSDOM.fromURL(url, {}).then(async dom => {
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
        console.error("We've got a new release! \\o/");
        console.error(`${url}/${matches[0]}`);
        console.error("Old:");
        console.error(`${url}/${latestDate}/`);
        // Get the new bone-debian image
        var newVar = await getNewBoneDebian(`${url}/${matches[0]}buster-console`)
        console.log(`newVar: ${newVar}`)
        if (newVar) {
            console.log("## Auto-update")
            console.log(`# latestDate: ${matches[0]}`)
            console.log(`${newVar}`)
        }
    }
});
