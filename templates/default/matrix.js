
function toggleRecipient(element) 
{
    element.getAllNext('td').each(function(el, i) {
        el.getChildren('input').each(function(inel, ini) {
            inel.checked = !inel.checked;
        });
    });
}

window.addEvent('domready', function() {
    $$('td.recip').each(function(element, index) {
        element.addEvent('click', function() { toggleRecipient(element) });
    });
});


        
        