
function persistWarning() {
    var persist = $('persist').checked;

    if(persist) {
        $('persistwarn').reveal();
    } else {
        $('persistwarn').dissolve();
    }
}

function prefixMode() {
    var prefix = $('prefix_id').options[$('prefix_id').selectedIndex].value;

    if(prefix == "0") {
        $('prefix_other').disabled = false;
    } else {
        $('prefix_other').disabled = true;
    }
}

function replytoMode() {
    var replyto = $('replyto_id').options[$('replyto_id').selectedIndex].value;

    if(replyto == "0") {
        $('replyto_other').disabled = false;
    } else {
        $('replyto_other').disabled = true;
    }
}

function addExtraRow($rownum, $mode) {
    $('add' + $mode + $rownum).fade('out');
    if($rownum > 1) {
        $('del' + $mode + $rownum).fade('out');
    }
    $($mode + ($rownum + 1) + 'row').reveal();
}

function delExtraRow($rownum, $mode) {
    $($mode + $rownum + 'row').dissolve();
    $('add' + $mode + ($rownum - 1)).fade('in');
    if($rownum > 2) {
        $('del' + $mode + ($rownum - 1)).fade('in');
    }
    $($mode + $rownum).set("value", '');
}
