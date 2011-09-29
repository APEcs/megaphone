## @file
# This file contains the implementation of the twitter message target.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    29 Sept 2011
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
package Target::Twitter;

## @class
# A simple twitter target implementation. Supported arguments are:
#
# consumer_key=<key>
# consumer_secret=<key>
# access_token=<key>
# access_token_secret=<key>
#
# All arguments are REQUIRED, otherwise the send will fail.

use strict;
use base qw(Target); # This class is a Target module
use Net::Twitter::Lite;


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

    # If there are any arguments to convert, split and store
    $self -> set_config($self -> {"args"}) if($self && $self -> {"args"});

    return $self;
}


# ============================================================================
#  General interface functions

## @method void set_config($args)
# Set the current configuration to the module to the values in the provided
# args string.
#
# @param args A string containing the new configuration.
sub set_config {
    my $self = shift;
    my $args = shift;

    $self -> {"args"} = $args;

    my @argbits = split(/;/, $self -> {"args"});

    $self -> {"args"} = {};
    foreach my $arg (@argbits) {
        my ($name, $value) = $arg =~ /^(\w+)=(.*)$/;

        $self -> {"args"} -> {$name} = $value;
    }
}

# ============================================================================
#  Message send functions

## @method $ send($message)
# Attempt to send the specified message as an email.
#
# @param message A reference to a hash containing the message to send.
# @return undef on success, an error message on failure.
sub send {
    my $self      = shift;
    my $message   = shift;

    my $nt = Net::Twitter::Lite->new(
        consumer_key        => $self -> {"args"} -> {"consumer_key"},
        consumer_secret     => $self -> {"args"} -> {"consumer_secret"},
        access_token        => $self -> {"args"} -> {"access_token"},
        access_token_secret => $self -> {"args"} -> {"access_token_secret"},
        ssl => 1,
        );

    my $result = eval { $nt -> update($message -> {"message"}) };

    warn "$@\n" if($@);
}

1;
