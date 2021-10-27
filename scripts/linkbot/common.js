const fs = require('fs');
const updateURLLink = (newLine, target) => {
    try {
        const data = fs.readFileSync('../test/run-tests.sh', 'utf8')
              .replace(RegExp(`## Auto-update\n${target}=.*`), `## Auto-update\n${newLine}`);
        fs.writeFile('../test/run-tests.sh', data, (err, data) => {
            if (err) {
                console.error(err);
            }
        });
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
};
module.exports = {
    updateURLLink
};
