const path = require("path");

module.exports = {
  entry: {
    background_scripts: "./addon/src/background.js"
  },
  mode: "production",
  output: {
    path: path.resolve(__dirname, "addon", "dist"),
    filename: "background.js"
  }
};
