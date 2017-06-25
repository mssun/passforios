var PassProcessor = function() {};

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
        }
    }
    
    if (arguments["username"]) {
        var usernameElement = document.querySelector("input[type=email], input[type=text]")
        if (usernameElement) {
            usernameElement.setAttribute('value', arguments["username"])
            usernameElement.value = arguments["username"]
        }
    }
}
};

// The JavaScript file must contain a global object named "ExtensionPreprocessingJS".
var ExtensionPreprocessingJS = new PassProcessor;
