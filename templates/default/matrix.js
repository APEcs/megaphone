
function toggleRecipient(element) 
{
    element.getChildren('td').each(function(el, i) {
        el.getChildren('input').each(function(inel, ini) {
            inel.checked = !inel.checked;
        });
    });
}

window.addEvent('domready', function() {
    $$('tr.recip').each(function(element, index) {
        element.addEvent('click', function() { toggleRecipient(element) });
    });
});


        
        