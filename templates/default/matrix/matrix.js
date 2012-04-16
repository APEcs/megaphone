
function getTargetClass(element)
{
    var classes   = element.get('class');
    var classPatt = /target\-\w+/;

    return classPatt.exec(classes);
}

/** Toggle the recipients on a given row.
 *  
 * @param element A div element corresponding to the name on the row to toggle.
 */
function toggleRecipient(element) 
{
    var id = element.get('id');
    var firstTD = $("recip_" + id.substr(5));

    firstTD.getAllNext('td').each(function(el, i) {
        el.getChildren('input').each(function(inel, ini) {
            inel.checked = !inel.checked;
            var className = getTargetClass(inel);
            matrixClick(className[0]);
        });
    });
}


function toggleTree(element)
{
    var imgid  = element.get('id'); // The element is an img, the id will be tog_<id>
    var rowid  = imgid.substr(4);    // Get the id we are interested in

    var isclosed = element.hasClass('close');
    if(isclosed) {
        element.removeClass('close');
        element.addClass('open');
        element.set('src', 'templates/default/images/blockopen.png');
    } else {
        element.removeClass('open');
        element.addClass('close');
        element.set('src', 'templates/default/images/blockclose.png');
    }

    // Handle folding of recipients...
    $$('tr.reciprow').each(function(el, i) {
        var id = el.get('id');

        // Anything that starts with the rowid, but does not equal it, needs to be handled
        if((id.substr(1, rowid.length) == rowid) && (id != ("r"+rowid))) {
            if(isclosed) {
                el.setStyle('display', 'table-row');
            } else {
                el.setStyle('display', 'none');
            }
        }
    });

    var zebra = new ZebraTable();
    zebra.zebraize($('matrix'));   
}


function matrixClick(target)
{
    var checked = 0;

    // don't bother doing anything if there is no matching target
    if(target && $(target)) {
        
        // count how many checked checkboxes there are with the target class
        $$('input.'+target).each(function(element, index) {
            if(element.checked) ++checked;
        });

        // If there are any checked, show the stuff with the target id
        if(checked) {
            $(target).show();
        } else {
            $(target).hide();
        }
    }
}


function initTargets() 
{
    matrixTargList.each(function(targ, index) {
        matrixClick("target-"+targ);
    });
}


window.addEvent('domready', function() {
    $$('span.recipient').each(function(element, index) {
        element.addEvent('click', function() { toggleRecipient(element) });
    });

    $$('img.treetoggle').each(function(element, index) {
        element.addEvent('click', function() { toggleTree(element); });
    });

    initTargets();
});

        
        