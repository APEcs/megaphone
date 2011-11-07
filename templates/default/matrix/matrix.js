
function toggleRecipient(element) 
{
    if(element.hasClass('parent')) {
        var tdid   = element.get('id'); // The element is a td, the id will be recip_<id>
        var rowid  = tdid.substr(6);    // Get the id we are interested in
        var rowdiv = element.getElement('div');

        var isclosed = element.hasClass('closed');
        if(isclosed) {
            element.removeClass('closed');
            element.addClass('open');
            rowdiv.removeClass('closed');
            rowdiv.addClass('open');
        } else {
            element.removeClass('open');
            element.addClass('closed');
            rowdiv.removeClass('open');
            rowdiv.addClass('closed');
        }
        
        // Handle folding of recipients...
        $$('tr.reciprow').each(function(el, i) {
             var id = el.get('id');

             // Anything that starts with the rowid, but does not equal it, needs to be handled
             if((id.substring(0, rowid.length) == rowid) && (id != rowid)) {
                 if(isclosed) {
                     el.setStyle('display', 'table-row');
                 } else {
                     el.setStyle('display', 'none');
                 }
             }
        });

        var zebra = new ZebraTable();
        zebra.zebraize($('matrix'));
    } else {
        element.getAllNext('td').each(function(el, i) {
            el.getChildren('input').each(function(inel, ini) {
                inel.checked = !inel.checked;
                matrixClick(inel.get('class'));
            });
        });
    }
}


function matrixClick(target)
{
    var checked = 0;

    // don't bother doing anything if there is no matching target
    if($(target)) {
        
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
    $$('td.recip').each(function(element, index) {
        element.addEvent('click', function() { toggleRecipient(element) });
    });

    initTargets();
});

        
        