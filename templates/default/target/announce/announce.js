function date_disable(datefield, control) {
    var checked = $(control).get("checked");

    $(datefield + "_pick").set("disabled", checked);

    // clear the contents if the field is disabled
    if(checked) {
        $(datefield + "_pick").set('value', '');
        $(datefield).set('value', '');
    }
}

function show_disable(showfield, control) {
    var checked = $(control).get("checked");
    
    if(checked) {
        $(showfield).set("disabled", true);
        $(showfield).set("checked", false); 
    } else {
        $(showfield).set("disabled", false);
    }
}

window.addEvent('domready', function() {
    Locale.use('en-GB')
    new Picker.Date($('open_date_pick'), { 
                        timePicker: true, 
                        yearPicker: true, 
                        positionOffset: {x: 5, y: 0}, 
                        pickerClass: 'datepicker_dashboard', 
                        useFadeInOut: !Browser.ie,
                        onSelect: function(date){ 
                            $('open_date').set('value', date.format('%s')); 
                        }  
    });
    new Picker.Date($('close_date_pick'), { 
                        timePicker: true, 
                        yearPicker: true, 
                        positionOffset: {x: 5, y: 0}, 
                        pickerClass: 'datepicker_dashboard', 
                        useFadeInOut: !Browser.ie,
                        onSelect: function(date){ 
                            $('close_date').set('value', date.format('%s')); 
                        }   
    });

    date_disable('open_date', 'open_ignore');
    date_disable('close_date', 'close_ignore');
    show_disable('show_close', 'close_ignore');                
});
