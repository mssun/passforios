var PassProcessor = function() {};

PassProcessor.prototype = {
run: function(arguments) {
    var url
    var html
    var error
    try {
        url = document.URL;
        html = document.body.innerHTML
    } catch (e) {
        error = e
    } finally {
        arguments.completionFunction({"url": url, "html": html, "error": error});
    }
},
    
finalize: function(arguments) {
    var str = "username: " + arguments["username"] + "\r\npassword: " + arguments["password"];
    alert(str)
    // document.body.innerHTML = arguments["content"];
}
};

// The JavaScript file must contain a global object named "ExtensionPreprocessingJS".
var ExtensionPreprocessingJS = new PassProcessor;
