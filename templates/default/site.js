
function persistWarning() {
    var persist = $('persist').checked;

    if(persist) {
        $('persistwarn').reveal();
    } else {
        $('persistwarn').dissolve();
    }
}

function prefixMode() {
    if($('prefix_id')) {
        var prefix = $('prefix_id').options[$('prefix_id').selectedIndex].value;

        if(prefix == "0") {
            $('prefix_other').disabled = false;
        } else {
            $('prefix_other').disabled = true;
            $('prefix_other').set('value', '');
        }
    }
}

window.addEvent('domready', function() { 
    prefixMode();
});
