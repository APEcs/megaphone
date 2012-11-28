var pickers = new Array();

function date_disable(datefield, control, mode) {
    var checked = $(control).get("checked");

    $(datefield + "_pick").set("disabled", checked);

    // clear the contents if the field is disabled
    if(checked) {
        $(datefield + "_pick").set('value', '');
        $(datefield).set('value', '');
    } else {
        var now = new Date();

        var offset = (mode == 'close') ? 7 : 0;
        var targdate = new Date(now.getTime() + (offset * 86400000));

        $(datefield).set('value', targdate.getTime() / 1000);
        pickers[mode].select(targdate);
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
                    Locale.use('en-GB');
                    pickers['open'] = new Picker.Date($('open_date_pick'), {
                                          timePicker: true,
                                          yearPicker: true,
                                          positionOffset: {x: 5, y: 0},
                                          pickerClass: 'datepicker_dashboard',
                                          useFadeInOut: !Browser.ie,
                                          onSelect: function(date){
                                              $('open_date').set('value', date.format('%s'));
                                          }
                                      });
                    pickers['close'] = new Picker.Date($('close_date_pick'), {
                                                           timePicker: true,
                                                           yearPicker: true,
                                                           positionOffset: {x: 5, y: 0},
                                                           pickerClass: 'datepicker_dashboard',
                                                           useFadeInOut: !Browser.ie,
                                                           onSelect: function(date){
                                                               $('close_date').set('value', date.format('%s'));
                                                           }
                                                       });

                    date_disable('open_date', 'open_ignore', 'open');
                    date_disable('close_date', 'close_ignore', 'close');
                    show_disable('show_close', 'close_ignore');
                });
