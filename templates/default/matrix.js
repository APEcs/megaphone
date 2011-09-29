
function toggleRecipient(element) 
{
    element.getAllNext('td').each(function(el, i) {
        el.getChildren('input').each(function(inel, ini) {
            inel.checked = !inel.checked;

            matrixClick(inel.get('class'));
        });
    });
}


function matrixClick(target)
{
    var checked = 0;

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


function initTargets(element) 
{
    element.getAllNext('td').each(function(el, i) {
        el.getChildren('input').each(function(inel, ini) {
            matrixClick(inel.get('class'));
        });
    });
    
}


window.addEvent('domready', function() {
    $$('td.recip').each(function(element, index) {
        element.addEvent('click', function() { toggleRecipient(element) });

        if(index == 0) initTargets(element);
    });
});

        
        