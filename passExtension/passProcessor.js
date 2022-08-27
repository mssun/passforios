var PassProcessor = function() {};

/**
 * Dispatches a synthetic event of a given type on a given element.
 * @param {string} type the event type to dispatch
 * @param {Element} el the element upon which to dispatch it
 */
var dispatchEvent = function(type, el) {
    var evt = document.createEvent('Event');
    evt.initEvent(type, true, true);
    el.dispatchEvent(evt);
};

PassProcessor.prototype = {
run: function(arguments) {
    var url
    var error
    try {
        url = document.URL
    } catch (e) {
        error = e
    } finally {
        arguments.completionFunction({"url_string": url, "error": error});
    }
},

finalize: function(arguments) {
    if (arguments["password"]) {
        var passwordElement = document.querySelector("input[type=password]")
        if (passwordElement) {
            passwordElement.setAttribute('value', arguments["password"])
            passwordElement.value = arguments["password"]
            dispatchEvent("input", passwordElement)
            dispatchEvent("change", passwordElement)
        }
    }

    if (arguments["username"]) {
        var usernameElement = document.querySelector("input[type=email], input[type=text]")
        if (usernameElement) {
            usernameElement.setAttribute('value', arguments["username"])
            usernameElement.value = arguments["username"]
            dispatchEvent("input", usernameElement)
            dispatchEvent("change", usernameElement)
        }
    }
}
};

// The JavaScript file must contain a global object named "ExtensionPreprocessingJS".
var ExtensionPreprocessingJS = new PassProcessor;
