
/** Obtain get query string arguments.
 *
 * @param key The parameter key to search for in the url's query string (can also be "#" for the element anchor)
 * @param url The url to check for "key" in, location.href is used if not supplied.
 * @return the value of the variable for the provided key, or an object with the current GET variables plus
 *         the element anchor (if any). "" if the variable is not present in the given query string
 * @see http://webfreak.no/wp/2007/09/05/get-for-mootools-a-way-to-read-get-variables-with-javascript-in-mootools/
*/
function $get(key,url) {
    if(arguments.length < 2) url =location.href;
    if(arguments.length > 0 && key != ""){
        if(key == "#"){
            var regex = new RegExp("[#]([^$]*)");
        } else if(key == "?"){
            var regex = new RegExp("[?]([^#$]*)");
        } else {
            var regex = new RegExp("[?&]"+key+"=([^&#]*)");
        }
        var results = regex.exec(url);
        return (results == null )? "" : results[1];
    } else {
        url = url.split("?");
        var results = {};
        if(url.length > 1){
            url = url[1].split("#");
            if(url.length > 1) results["hash"] = url[1];
            url[0].split("&").each(function(item,index){
                item = item.split("=");
                results[item[0]] = item[1];
            });
        }
        return results;
    }
}