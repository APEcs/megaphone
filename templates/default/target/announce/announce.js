function date_disable(datefield, control) {
    var checked = $(control).get("checked");

    $(datefield).set("disabled", checked);

    // clear the contents if the field is disabled
    if(checked) {
        $(datefield).set('value', '');
    }
}

window.addEvent('domready', function() {
    Locale.use('en-GB')
    new Picker.Date($('open_date'), { 
                        timePicker: true, 
                        positionOffset: {x: 5, y: 0}, 
                        pickerClass: 'datepicker_dashboard', 
                        useFadeInOut: !Browser.ie 
    });
    new Picker.Date($('close_date'), { 
                        timePicker: true, 
                        positionOffset: {x: 5, y: 0}, 
                        pickerClass: 'datepicker_dashboard', 
                        useFadeInOut: !Browser.ie 
    });

    date_disable('open_date', 'open_ignore');
    date_disable('close_date', 'close_ignore');
});
