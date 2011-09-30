var CountArea = new Class(
{
    //implements
    Implements: [Options,Events],

    // options
    options:
    {
        divCount: 'counter',
        twitter: 140,
        twitterokay: 'twitokay',
        twitterlong: 'twitlong',
        twittermode: 'tweet_mode',
        modetrunc: 1,
        modesplit: 2,
    },

        // initialization
    initialize: function(options)
    {
        //set options
        this.setOptions(options);
    },

    // Add the counter area and keypress handler
    addCounter: function(textarea) {
        // Make the counter div and initialise it
        this.options.countDiv = new Element('div', {'class': this.options.divCount});
        this.getCount(textarea.get('value'));

        // Shove the div in after the textarea
        textarea.getParent().adopt(this.options.countDiv);

        // Attach events
        textarea.addEvent('keyup', function() {
            this.getCount(textarea.get('value'));
        }.bind(this));
    },

    getCount: function(text) {
        var numChars = text.length;

        var counter = "Characters used: "+numChars;
        if(this.options.twitter) {
            if(numChars <= this.options.twitter) {
                counter += ' (Twitter: <span class="'+this.options.twitterokay+'">'+(this.options.twitter - numChars)+" chars left</span>)";
            } else {
                // Long tweet, see what we should be doing with it...
                var mode = $(this.options.twittermode).options[$(this.options.twittermode).selectedIndex].value;

                if(mode == this.options.modetrunc) {
                    counter += ' (Twitter: <span class="'+this.options.twitterlong+'">message will be truncated</span>)';
                } else if(mode == this.options.modesplit) {
                    var tweets = Math.floor(numChars / 140);
                    var tcars  = 140 - (numChars - (tweets * 140));

                    counter += ' (Twitter: <span class="'+this.options.twitterokay+'">'+(tweets + 1)+" tweets, "+tcars+" chars left in last tweet</span>)";
                }
            }
        }
        this.options.countDiv.set('html', counter);
    }
});

// Add message length counters to all 'countarea' text areas
function doCounter()
{
    $$('textarea.countarea').each(function(element,index) {
        var countArea = new CountArea();
        countArea.addCounter(element);
    });
}

// When the dom is ready to process, do it.
window.addEvent('domready', function() {
        doCounter();
});
