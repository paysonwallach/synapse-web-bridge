"use strict";

(function () {
  const Constants = {
    HOST_CONNECTOR: "com.paysonwallach.synapse_firefox.connector",
  };

  const MessageType = {
    COMMAND: "command",
    QUERY: "query",
  };

  var sizeof = require("object-sizeof");

  var port = browser.runtime.connectNative(Constants.HOST_CONNECTOR);
  var results = [];

  port.onMessage.addListener((message) => {
    console.log(message);
    switch (message.type) {
      case MessageType.QUERY:
        var bookmarks_results = browser.bookmarks.search({
          query: message.body,
        });
        var history_results = browser.history.search({ text: message.body });

        Promise.all([history_results, bookmarks_results])
          .then((values) => {
            values.forEach((value) => {
              results.push(
                ...value
                  .filter(
                    (i) =>
                      i.url &&
                      !results.includes(i.url) &&
                      sizeof({
                        title:
                          i.title != null ? i.title : new URL(i.url).hostname,
                        description: null,
                        url: i.url,
                      }) < 1024 // max size of a message is 1 Mb
                  )
                  .sort((a, b) =>
                    a.visitCount < b.visitCount
                      ? 1
                      : a.visitCount === b.visitCount
                      ? a.lastVisitTime < b.lastVisitTime
                        ? 1
                        : -1
                      : -1
                  )
              );
            });
            var results_size = 0;
            port.postMessage(results.length);
            results.forEach((result) => {
              var page_match = {
                title:
                  result.title != ""
                    ? result.title
                    : new URL(result.url).hostname,
                description: null,
                url: result.url,
              };
              if ((results_size += sizeof(page_match)) < 65536) {
                // max pipe capacity on unix
                port.postMessage(page_match);
              }
            });
            results.length = 0;
          })
          .catch((error) => {
            console.log(error);
            port.postMessage(results);
          });

        break;
      case MessageType.COMMAND:
        var tabs_result = browser.tabs.query({ url: message.body });
        var current_window = browser.windows.getCurrent();

        tabs_result.then(
          (results) => {
            if (results.length != 0) {
              browser.tabs.update(results[0].id, { active: true });

              browser.windows.update(results[0].windowId, { focused: true });
            } else {
              browser.tabs.create({
                active: true,
                url: message.body,
              });

              current_window.then((result) => {
                browser.windows.update(result.id, { focused: true });
              });
            }
          },
          (error) => {
            console.log(
              `error retrieving tab with url '${message.body}': ${error}`
            );
          }
        );

        results.length = 0;
        break;
      default:
        console.log(`unknown option: ${message.type}`);
    }
  });

  port.postMessage(); // start host connector
})();
