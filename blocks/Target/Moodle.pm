## @file
# This file contains the implementation of the moodle message target.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    21 Sept 2011
# @copy    2011, Chris Page &lt;chris@starforge.co.uk&gt;
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
package Target::Moodle;

use strict;
use base qw(MegaphoneBlock); # This class extends MegaphoneBlock

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# An overridden constructor, required to correctly parse out settings for the
# message sender.
#
# @param args A hash of arguments to initialise the object with
# @return A blessed reference to the object
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_);

    if($self) {
        # If there are any arguments to convert, split and store
        if($self -> {"args"}) {
            my @argbits = split(/;/, $self -> {"args"});
            
            $self -> {"args"} = {};
            foreach my $arg (@argbits) {
                my ($name, $value) = $arg =~ /^(\w+)=(.*)$/;
                $self -> {"args"} -> {$name} = $value;
            }
        }
    }
    return $self;
}


# ============================================================================
#  Message send functions

## @method $ send($message)
# Attempt to send the specified message as a moodle forum post. 
#
# @param message A reference to a hash containing the message to send.
# @return undef on success, an error message on failure.
sub send {
    my $self    = shift;
    my $message = shift;



}

1;
