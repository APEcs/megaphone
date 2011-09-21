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
        textarea.parentElement.adopt(this.options.countDiv);

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
                counter += ' (Twitter: <span class="'+this.options.twitterlong+'">message too long</span>)';
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
