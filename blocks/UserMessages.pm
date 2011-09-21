## @file
# This file contains the implementation of the user message manipulation code.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    19 Sept 2011
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
package UserMessages;

use strict;
use base qw(MegaphoneBlock); # This class extends MegaphoneBlock
use MIME::Base64;   # Needed for base64 encoding of popup bodies.
use Logging qw(die_log);
use Utils qw(is_defined_numeric);


# ============================================================================
#  Sort functions

# Attach weights to each visible state, so we can sort them by something
# other than alphanumeric comparison (which will usually not be what is wanted)
my $stateweight = {"incomplete" => 0,
                   "pending"    => 1,
                   "sent"       => 2,
                   "edited"     => 3,
                   "aborted"    => 4};

sub sortfn_state_asc {
    my $statea = $a ? $stateweight -> {$a -> {"status"}} : 0;
    my $stateb = $b ? $stateweight -> {$b -> {"status"}} : 0;
    my $res = $statea <=> $stateb;
    return $res if($res); # If the result is non-zero, the states differ

    # States are the same, compare subjects
    my $subja = $a ? $a -> {"subject"} : "";
    my $subjb = $b ? $b -> {"subject"} : "";
    $res = $subja cmp $subjb;
    return $res if($res); # If the result is non-zero, the subjects differ

    # Subjects and states match, try updated?
    my $updatea = $a ? $a -> {"updated"} : 0;
    my $updateb = $b ? $b -> {"updated"} : 0;
    return $updatea <=> $updateb;
}

sub sortfn_state_desc {
    my $statea = $a ? $stateweight -> {$a -> {"status"}} : 0;
    my $stateb = $b ? $stateweight -> {$b -> {"status"}} : 0;

    my $res = $stateb <=> $statea;
    return $res if($res); # If the result is non-zero, the states differ

    # States are the same, compare subjects
    my $subja = $a ? $a -> {"subject"} : "";
    my $subjb = $b ? $b -> {"subject"} : "";
    $res = $subjb cmp $subja;
    return $res if($res); # If the result is non-zero, the subjects differ

    # Subjects and states match, try updated?
    my $updatea = $a ? $a -> {"updated"} : 0;
    my $updateb = $b ? $b -> {"updated"} : 0;
    return $updateb <=> $updatea;
}

sub sortfn_subject_asc {
    my $subja = $a ? $a -> {"subject"} : "";
    my $subjb = $b ? $b -> {"subject"} : "";
    my $res = $subja cmp $subjb;
    return $res if($res); # If the result is non-zero, the subjects differ

    # subjects are the same, compare statess
    my $statea = $a ? $stateweight -> {$a -> {"status"}} : 0;
    my $stateb = $b ? $stateweight -> {$b -> {"status"}} : 0;
    $res = $statea <=> $stateb;
    return $res if($res); # If the result is non-zero, the states differ

    # Subjects and states match, try updated?
    my $updatea = $a ? $a -> {"updated"} : 0;
    my $updateb = $b ? $b -> {"updated"} : 0;
    return $updatea <=> $updateb;
}

sub sortfn_subject_desc {
    my $subja = $a ? $a -> {"subject"} : "";
    my $subjb = $b ? $b -> {"subject"} : "";
    my $res = $subjb cmp $subja;
    print "Comparing $subjb cmp $subja = $res\n";
    return $res if($res); # If the result is non-zero, the subjects differ

    # subjects are the same, compare statess
    my $statea = $a ? $stateweight -> {$a -> {"status"}} : 0;
    my $stateb = $b ? $stateweight -> {$b -> {"status"}} : 0;
    $res = $stateb <=> $statea;
    return $res if($res); # If the result is non-zero, the states differ

    # Subjects and states match, try updated?
    my $updatea = $a ? $a -> {"updated"} : 0;
    my $updateb = $b ? $b -> {"updated"} : 0;
    return $updateb <=> $updatea;
}

sub sortfn_updated_asc {
    my $updatea = $a ? $a -> {"updated"} : 0;
    my $updateb = $b ? $b -> {"updated"} : 0;
    my $res = $updatea <=> $updateb;
    return $res if($res); # If the result is non-zero, the update times differ

    # update times match, check states
    my $statea = $a ? $stateweight -> {$a -> {"status"}} : 0;
    my $stateb = $b ? $stateweight -> {$b -> {"status"}} : 0;
    $res = $statea <=> $stateb;
    return $res if($res); # If the result is non-zero, the states differ

    # States match, check subjects
    my $subja = $a ? $a -> {"subject"} : "";
    my $subjb = $b ? $b -> {"subject"} : "";
    return $subja cmp $subjb;
}

sub sortfn_updated_desc {
    my $updatea = $a ? $a -> {"updated"} : 0;
    my $updateb = $b ? $b -> {"updated"} : 0;
    my $res = $updateb <=> $updatea;
    return $res if($res); # If the result is non-zero, the update times differ

    # update times match, check states
    my $statea = $a ? $stateweight -> {$a -> {"status"}} : 0;
    my $stateb = $b ? $stateweight -> {$b -> {"status"}} : 0;
    $res = $stateb <=> $statea;
    return $res if($res); # If the result is non-zero, the states differ

    # States match, check subjects
    my $subja = $a ? $a -> {"subject"} : "";
    my $subjb = $b ? $b -> {"subject"} : "";
    return $subjb cmp $subja;
}

sub sortfn_sent_asc {
    my $senta = $a ? ($a -> {"sent"} || 0) : 0;
    my $sentb = $b ? ($b -> {"sent"} || 0) : 0;
    my $res = $senta <=> $sentb;
    return $res if($res); # If the result is non-zero, the sent times differ

    my $updatea = $a ? $a -> {"updated"} : 0;
    my $updateb = $b ? $b -> {"updated"} : 0;
    $res = $updatea <=> $updateb;
    return $res if($res); # If the result is non-zero, the update times differ

    # update times match, check states
    my $statea = $a ? $stateweight -> {$a -> {"status"}} : 0;
    my $stateb = $b ? $stateweight -> {$b -> {"status"}} : 0;
    $res = $statea <=> $stateb;
    return $res if($res); # If the result is non-zero, the states differ

    # States match, check subjects
    my $subja = $a ? $a -> {"subject"} : "";
    my $subjb = $b ? $b -> {"subject"} : "";
    return $subja cmp $subjb;
}

sub sortfn_sent_desc {
    my $senta = $a ? ($a -> {"sent"} || 0) : 0;
    my $sentb = $b ? ($b -> {"sent"} || 0) : 0;
    my $res = $sentb <=> $senta;
    return $res if($res); # If the result is non-zero, the sent times differ

    my $updatea = $a ? $a -> {"updated"} : 0;
    my $updateb = $b ? $b -> {"updated"} : 0;
    $res = $updateb <=> $updatea;
    return $res if($res); # If the result is non-zero, the update times differ

    # update times match, check states
    my $statea = $a ? $stateweight -> {$a -> {"status"}} : 0;
    my $stateb = $b ? $stateweight -> {$b -> {"status"}} : 0;
    $res = $stateb <=> $statea;
    return $res if($res); # If the result is non-zero, the states differ

    # States match, check subjects
    my $subja = $a ? $a -> {"subject"} : "";
    my $subjb = $b ? $b -> {"subject"} : "";
    return $subjb cmp $subja;
}

sub sortfn_visible_asc {
    my $visa = $a ? ($a -> {"sent"} || 0) : 0;
    my $visb = $b ? ($b -> {"sent"} || 0) : 0;
    my $res = $visa <=> $visb;
    return $res if($res); # If the result is non-zero, the sent times differ

    my $updatea = $a ? $a -> {"updated"} : 0;
    my $updateb = $b ? $b -> {"updated"} : 0;
    $res = $updatea <=> $updateb;
    return $res if($res); # If the result is non-zero, the update times differ

    # update times match, check states
    my $statea = $a ? $stateweight -> {$a -> {"status"}} : 0;
    my $stateb = $b ? $stateweight -> {$b -> {"status"}} : 0;
    $res = $statea <=> $stateb;
    return $res if($res); # If the result is non-zero, the states differ

    # States match, check subjects
    my $subja = $a ? $a -> {"subject"} : "";
    my $subjb = $b ? $b -> {"subject"} : "";
    return $subja cmp $subjb;
}

sub sortfn_visible_desc {
    my $visa = $a ? ($a -> {"sent"} || 0) : 0;
    my $visb = $b ? ($b -> {"sent"} || 0) : 0;
    my $res = $visb <=> $visa;
    return $res if($res); # If the result is non-zero, the sent times differ

    my $updatea = $a ? $a -> {"updated"} : 0;
    my $updateb = $b ? $b -> {"updated"} : 0;
    $res = $updateb <=> $updatea;
    return $res if($res); # If the result is non-zero, the update times differ

    # update times match, check states
    my $statea = $a ? $stateweight -> {$a -> {"status"}} : 0;
    my $stateb = $b ? $stateweight -> {$b -> {"status"}} : 0;
    $res = $stateb <=> $statea;
    return $res if($res); # If the result is non-zero, the states differ

    # States match, check subjects
    my $subja = $a ? $a -> {"subject"} : "";
    my $subjb = $b ? $b -> {"subject"} : "";
    return $subjb cmp $subja;
}


# Store references to the sort functions in a hash so that we can call them
# using sort { $sortfns -> {$sort} -> {$way} -> () } @{$values} rather than
# needing a mess of if()/elsif()/else code.
my $sortfns = { "status"  => {"asc"  => \&sortfn_state_asc,
                              "desc" => \&sortfn_state_desc},
                "subject" => {"asc"  => \&sortfn_subject_asc,
                              "desc" => \&sortfn_subject_desc},
                "updated" => {"asc"  => \&sortfn_updated_asc,
                              "desc" => \&sortfn_updated_desc},
                "sent"    => {"asc"  => \&sortfn_sent_asc,
                              "desc" => \&sortfn_sent_desc},
                "visible" => {"asc"  => \&sortfn_visible_asc,
                              "desc" => \&sortfn_visible_desc},
            };


# ============================================================================
#  Validation functions

## @method $ check_abort()
# Determine whether the message selected by the user can be aborted, including
# verifying that the message has been specified, and is cancellable.
#
# @return A reference to the message data if it can be cancelled, or a string
#         containing an error page if it can't
sub check_abort {
    my $self = shift;

    # Get the message id...
    my $msgid = is_defined_numeric($self -> {"cgi"}, "msgid");
    return $self -> generate_fatal($self -> {"template"} -> replace_langvar("FATAL_NOMSGID")) if(!$msgid);

    # Get the message data
    my $message = $self -> get_message($msgid);
    return $self -> generate_fatal($self -> {"template"} -> replace_langvar("FATAL_BADMSGID")) if(!$message);

    # Can't cancel messages unless they are 'pending'
    return $self -> generate_fatal($self -> {"template"} -> replace_langvar("FATAL_MSGNOKILL")) unless($message -> {"status"} eq "pending");

    return $message;
}


## @method $ check_edit()
# Determine whether the message selected by the user can be edited, including
# verifying that the message has been specified, and is editable.
#
# @return A reference to the message data if it can be edited, or a string
#         containing an error page if it can't
sub check_edit {
    my $self = shift;

    # Get the message id...
    my $msgid = is_defined_numeric($self -> {"cgi"}, "msgid");
    return $self -> generate_fatal($self -> {"template"} -> replace_langvar("FATAL_NOMSGID")) if(!$msgid);

    # Get the message data
    my $message = $self -> get_message($msgid);
    return $self -> generate_fatal($self -> {"template"} -> replace_langvar("FATAL_BADMSGID")) if(!$message);

    # Can't edit messages unless they are incomplete, pending, or aborted
    return $self -> generate_fatal($self -> {"template"} -> replace_langvar("FATAL_MSGNOEDIT"))
        unless($message -> {"status"} eq "incomplete" || $message -> {"status"} eq "pending" || $message -> {"status"} eq "aborted");

    return $message;
}


## @method $ check_send()
# Determine whether the message selected by the user can be sent immediately including
# verifying that the message has been specified, and is sendable.
#
# @return A reference to the message data if it can be sent, or a string
#         containing an error page if it can't
sub check_send {
    my $self = shift;

    # Get the message id...
    my $msgid = is_defined_numeric($self -> {"cgi"}, "msgid");
    return $self -> generate_fatal($self -> {"template"} -> replace_langvar("FATAL_NOMSGID")) if(!$msgid);

    # Get the message data
    my $message = $self -> get_message($msgid);
    return $self -> generate_fatal($self -> {"template"} -> replace_langvar("FATAL_BADMSGID")) if(!$message);

    # Can't send messages unless they are pending
    return $self -> generate_fatal($self -> {"template"} -> replace_langvar("FATAL_MSGNOSEND"))
        unless($message -> {"status"} eq "pending");

    return $message;
}


# ============================================================================
#  Fragment generators

## @method $ build_navigation($maxpage, $pagenum, $sort, $way)
# Generate the navigation/pagination box for the message list. This will generate
# a series of boxes and controls to allow users to move between pages of message
# list.
#
# @param maxpage The last page number (first is page 0).
# @param pagenum The selected page (first is page 0!!)
# @param sort    The current sort mode.
# @param way     The direction to sort in.
# @return A string containing the navigation block.
sub build_navigation {
    my $self    = shift;
    my $maxpage = shift;
    my $pagenum = shift;
    my $sort    = shift;
    my $way     = shift;

    # If there is more than one page, generate a full set of page controls
    if($maxpage > 0) {
        my $pagelist = "";

        # If the user is not on the first page, we need to add the left jump controls
        $pagelist .= $self -> {"template"} -> load_template("messagelist/jumpleft.tem", {"***sort***"   => $sort,
                                                                                                "***way***"    => $way,
                                                                                                "***prev***"   => $pagenum - 1})
            if($pagenum > 0);

        # load some templates to speed up page list generation...
        my $pagetem = $self -> {"template"} -> load_template("messagelist/jumppage.tem", {"***sort***"   => $sort,
                                                                                                 "***way***"    => $way});
        my $pageacttem = $self -> {"template"} -> load_template("messagelist/page.tem");

        # Generate the list of pages
        for(my $pnum = 0; $pnum <= $maxpage; ++$pnum) {
            $pagelist .= $self -> {"template"} -> process_template(($pagenum == $pnum) ? $pageacttem : $pagetem,
                                                                   {"***pagenum***" => $pnum + 1,
                                                                    "***pageid***"  => $pnum});
        }

        # Append the right jump controls if we're not on the last page
        $pagelist .= $self -> {"template"} -> load_template("messagelist/jumpright.tem", {"***sort***"   => $sort,
                                                                                                 "***way***"    => $way,
                                                                                                 "***next***"   => $pagenum + 1,
                                                                                                 "***last***"   => $maxpage})
            if($pagenum < $maxpage);

        return $self -> {"template"} -> load_template("messagelist/paginate.tem", {"***pagenum***" => $pagenum + 1,
                                                                                          "***maxpage***" => $maxpage + 1,
                                                                                          "***pages***"   => $pagelist});
    # If there's only one page, a simple "Page 1 of 1" will do the trick.
    } else { # if($maxpage > 0)
        return $self -> {"template"} -> load_template("messagelist/paginate.tem", {"***pagenum***" => 1,
                                                                                          "***maxpage***" => 1,
                                                                                          "***pages***"   => ""});
    }
}


## @method $ build_sent_info($message)
# Generate a short string indicating when a message is going to be sent.
#
# @param message A reference to a hash containing the message's data.
# @return A string indicating when the message will be sent.
sub build_sent_info {
    my $self    = shift;
    my $message = shift;

    # find out how long is left...
    my $remain = $self -> delay_remain($message);

    # Unsendables get their own template...
    return $self -> {"template"} -> load_template("messagelist/unsendable.tem") if(!defined($remain));

    # Not sent yet when it should have been?
    return $self -> {"template"} -> load_template("messagelist/notsent.tem") if($remain == -1);

    # Not sent, waiting on delay timer
    my $class = ($remain > 600 ? "long" : ($remain > 120 ? "med" : "short")); 
    return $self -> {"template"} -> load_template("messagelist/delaywait.tem", {"***remain***" => $self -> {"template"} -> humanise_seconds($remain, 1),
                                                                                "***class***"  => $class});
}


## @method $ get_msglist_args($msgid)
# Create a hash containing the currently set message list options.
#
# @param msgid The message id being worked on.
# @return A reference to a hash containing the message list settings.
sub get_msglist_args {
    my $self  = shift;
    my $msgid = shift;

    my $args = { "msgid" => $msgid,
                 "sort" => $self -> {"cgi"} -> param("sort") || "updated",
                 "way"  => $self -> {"cgi"} -> param("way")  || "desc",
                 "page" => is_defined_numeric($self -> {"cgi"}, "page") || 0 };

    # Make sure the sort preferences are valid
    $args -> {"sort"} = "updated" unless($args -> {"sort"} eq "status" || $args -> {"sort"} eq "subject" || $args -> {"sort"} eq "updated" || $args -> {"sort"} eq "sent");
    $args -> {"way"}  = "desc" unless($args -> {"way"} eq "asc" || $args -> {"way"} eq "desc");
    $args -> {"page"} = 0 if($args -> {"page"} < 0);

    return $args;
}


# ============================================================================
#  Content generation functions

## @method $ generate_basic_messagepage($user, $info)
# A convenience function to generate the message list and userdetails page. This will
# create a basic view of the page, with optional info box. No errors can be shown
# via this.
#
# @param $user A reference to a hash containing the user's data.
# @param $info An optional info block to show in the page.
# @return The messagelist page content.
sub generate_basic_messagepage {
    my $self = shift;
    my $user = shift;
    my $info = shift;

    my $content = $self -> generate_messagelist(undef, $info);
    $content .= $self -> generate_userdetails_form({"email"    => $user -> {"email"},
                                                    "realname" => $user -> {"realname"},
                                                    "rolename" => $user -> {"rolename"},
                                                    "block"    => $self -> {"block"}});

    return $content;
}


## @method $ generate_abort_form($message, $extraargs)
# Generate a form prompting the user to confirm that a message should be aborted.
#
# @param messge A reference to a hash containing the message the user has selected to abort.
# @param extraargs Extra arguments to store in hidden input elements.
# @return The message abort confirmation form.
sub generate_abort_form {
    my $self      = shift;
    my $message   = shift;
    my $extraargs = shift;
    my $tem;

    $tem -> {"cc"}  = $self -> {"template"} -> load_template("blocks/message_confirm_cc.tem");
    $tem -> {"bcc"} = $self -> {"template"} -> load_template("blocks/message_confirm_bcc.tem");

    my $outfields;
    # work out the bcc/cc fields....
    foreach my $mode ("cc", "bcc") {
        for(my $i = 0; $i < 4; ++$i) {
            # Append the cc/bcc if it is set...
            $outfields -> {$mode} .= $self -> {"template"} -> process_template($tem -> {$mode}, {"***data***" => encode_entities($message -> {$mode} -> [$i])})
                if($message -> {$mode} -> [$i]);
        }
    }

    # Get the prefix sorted
    if($message -> {"prefix_id"} == 0) {
        $outfields -> {"prefix"} = $message -> {"prefixother"};
    } else {
        my $prefixh = $self -> {"dbh"} -> prepare("SELECT prefix FROM ".$self -> {"settings"} -> {"database"} -> {"prefixes"}."
                                                   WHERE id = ?");
        $prefixh -> execute($message -> {"prefix_id"})
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute prefix query: ".$self -> {"dbh"} -> errstr);

        my $prefixr = $prefixh -> fetchrow_arrayref();
        $outfields -> {"prefix"} = $prefixr ? $prefixr -> [0] : $self -> {"template"} -> replace_langvar("MESSAGE_BADPREFIX");
    }

    $outfields -> {"delaysend"} = $self -> {"template"} -> load_template($message -> {"delaysend"} ? "blocks/message_edit_delay.tem" : "blocks/message_edit_nodelay.tem",
                                                                         {"***delay***" => $self -> {"template"} -> humanise_seconds($self -> {"settings"} -> {"config"} -> {"Core:delaysend"})});

    # Simple HTML fix for the message...
    ($outfields -> {"message"} = $message -> {"message"}) =~ s/\n/<br \/>\n/g;

    # And build the message block itself. Kinda big and messy, this...
    my $body = $self -> {"template"} -> load_template("blocks/message_abort.tem", {"***targmatrix***"  => $self -> build_target_matrix($message -> {"targset"}, 1),
                                                                                   "***cc***"          => $outfields -> {"cc"},
                                                                                   "***bcc***"         => $outfields -> {"bcc"},
                                                                                   "***prefix***"      => $outfields -> {"prefix"},
                                                                                   "***subject***"     => $message -> {"subject"},
                                                                                   "***message***"     => $outfields -> {"message"},
                                                                                   "***delaysend***"   => $outfields -> {"delaysend"},
                                                                               });
    # store any hidden args...
    my $hiddenargs = "";
    my $hidetem = $self -> {"template"} -> load_template("hiddenarg.tem");
    foreach my $key (keys(%{$extraargs})) {
        $hiddenargs .= $self -> {"template"} -> process_template($hidetem, {"***name***"  => $key,
                                                                            "***value***" => $extraargs -> {$key}});
    }

    # Send back the form.
    return $self -> {"template"} -> load_template("form.tem", {"***content***" => $body,
                                                               "***args***"    => $hiddenargs,
                                                               "***block***"   => $self -> {"block"}});
}


## @method $ generate_view_form($message, $extraargs)
# Generate a form containing a copy of the selected message. Pretty similar to
# generate_abort_form(), but meh.
#
# @param messge    A reference to a hash containing the message the user has selected to abort.
# @param extraargs Extra arguments to store in hidden input elements.
# @return The message view form.
sub generate_view_form {
    my $self      = shift;
    my $message   = shift;
    my $extraargs = shift;
    my $tem;

    $tem -> {"cc"}  = $self -> {"template"} -> load_template("blocks/message_confirm_cc.tem");
    $tem -> {"bcc"} = $self -> {"template"} -> load_template("blocks/message_confirm_bcc.tem");

    my $outfields;
    # work out the bcc/cc fields....
    foreach my $mode ("cc", "bcc") {
        for(my $i = 0; $i < 4; ++$i) {
            # Append the cc/bcc if it is set...
            $outfields -> {$mode} .= $self -> {"template"} -> process_template($tem -> {$mode}, {"***data***" => encode_entities($message -> {$mode} -> [$i])})
                if($message -> {$mode} -> [$i]);
        }
    }

    # Get the prefix sorted
    if($message -> {"prefix_id"} == 0) {
        $outfields -> {"prefix"} = $message -> {"prefixother"};
    } else {
        my $prefixh = $self -> {"dbh"} -> prepare("SELECT prefix FROM ".$self -> {"settings"} -> {"database"} -> {"prefixes"}."
                                                   WHERE id = ?");
        $prefixh -> execute($message -> {"prefix_id"})
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute prefix query: ".$self -> {"dbh"} -> errstr);

        my $prefixr = $prefixh -> fetchrow_arrayref();
        $outfields -> {"prefix"} = $prefixr ? $prefixr -> [0] : $self -> {"template"} -> replace_langvar("MESSAGE_BADPREFIX");
    }

    $outfields -> {"delaysend"} = $self -> {"template"} -> load_template($message -> {"delaysend"} ? "blocks/message_edit_delay.tem" : "blocks/message_edit_nodelay.tem",
                                                                         {"***delay***" => $self -> {"template"} -> humanise_seconds($self -> {"settings"} -> {"config"} -> {"Core:delaysend"})});

    # Simple HTML fix for the message...
    ($outfields -> {"message"} = $message -> {"message"}) =~ s/\n/<br \/>\n/g;

    # And build the message block itself. Kinda big and messy, this...
    my $body = $self -> {"template"} -> load_template("blocks/message_view.tem", {"***targmatrix***"  => $self -> build_target_matrix($message -> {"targset"}, 1),
                                                                                   "***cc***"          => $outfields -> {"cc"},
                                                                                   "***bcc***"         => $outfields -> {"bcc"},
                                                                                   "***prefix***"      => $outfields -> {"prefix"},
                                                                                   "***subject***"     => $message -> {"subject"},
                                                                                   "***message***"     => $outfields -> {"message"},
                                                                                   "***delaysend***"   => $outfields -> {"delaysend"},
                                                                               });

    # store any hidden args...
    my $hiddenargs = "";
    my $hidetem = $self -> {"template"} -> load_template("hiddenarg.tem");
    foreach my $key (keys(%{$extraargs})) {
        $hiddenargs .= $self -> {"template"} -> process_template($hidetem, {"***name***"  => $key,
                                                                            "***value***" => $extraargs -> {$key}});
    }

    # Send back the form.
    return $self -> {"template"} -> load_template("form.tem", {"***content***" => $body,
                                                               "***args***"    => $hiddenargs,
                                                               "***block***"   => $self -> {"block"}});
}


## @method $ generate_messagelist($error, $info)
# Generate the list of messages to show to the user, including navigation controls.
#
# @param error An error message to show on the page. This will be wrapped in an error box for you.
# @param info An info box to show on the page. Will not be wrapped!
# @return A string containing the message list.
sub generate_messagelist {
    my $self  = shift;
    my $error = shift;
    my $info  = shift;

    # First stage; we need to get a list of the user's messages. All of them.
    # We can't rely on SQL LIMIT and ORDER BY to get it right, unfortunately.
    my $messh = $self -> {"dbh"} -> prepare("SELECT id, status, subject, updated, sent, visible, delaysend
                                             FROM ".$self -> {"settings"} -> {"database"} -> {"messages"}."
                                             WHERE user_id = ?");
    $messh -> execute($self -> {"session"} -> {"sessuser"})
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute message lookup query: ".$self -> {"dbh"} -> errstr);

    # Get a reference to an array of hashrefs, one entry per message
    my $messages = $messh -> fetchall_arrayref({});

    # Has the user specified any sorting preferences?
    my $sort = $self -> {"cgi"} -> param("sort") || "updated";
    my $way  = $self -> {"cgi"} -> param("way")  || "desc";

    # Make sure the sort preferences are valid
    $sort = "updated" unless($sort eq "status" || $sort eq "subject" || $sort eq "updated" || $sort eq "sent");
    $way  = "desc" unless($way eq "asc" || $way eq "desc");

    # Sort according to user preferences...
    my @sorted = sort { $sortfns -> {$sort} -> {$way} -> () } @{$messages};

    # Now the viewable splice can be extracted.
    # Find out how many pages there are...
    my $maxpage = int(scalar(@sorted) / $self -> {"settings"} -> {"config"} -> {"UserMessages:page_length"});

    # And which page the user is looking at
    my $pagenum   = is_defined_numeric($self -> {"cgi"}, "page") || 0;
    $pagenum = 0        if($pagenum < 0);
    $pagenum = $maxpage if($pagenum > $maxpage);

    # Get the splice. Probably a nicer way to do this, but hell, it works.
    my @spliced = splice(@sorted, $pagenum * $self -> {"settings"} -> {"config"} -> {"UserMessages:page_length"}, $self -> {"settings"} -> {"config"} -> {"UserMessages:page_length"});

    # Precache the row template to speed things up
    my $rowtem = $self -> {"template"} -> load_template("messagelist/row.tem", {"***sort***" => $sort,
                                                                                       "***way***"  => $way,
                                                                                       "***page***" => $pagenum});
    # Precache the ops templates for each status
    my $optems = {};
    foreach my $state (keys(%{$stateweight})) {
        $optems -> {$state} = $self -> {"template"} -> load_template("messagelist/op$state.tem", {"***sort***" => $sort,
                                                                                                          "***way***"  => $way,
                                                                                                          "***page***" => $pagenum});
    }

    # Visibility templates
    my @vistem = ($self -> {"template"} -> load_template("messagelist/invisible.tem"),
                  $self -> {"template"} -> load_template("messagelist/visible.tem"));

    # Process the rows...
    my $rows = "";
    foreach my $message (@spliced) {
        $rows .= $self -> {"template"} -> process_template($rowtem, {"***id***"      => $message -> {"id"},
                                                                     "***status***"  => $message -> {"status"},
                                                                     "***subject***" => $message -> {"subject"},
                                                                     "***updated***" => $self -> {"template"} -> format_time($message -> {"updated"}),
                                                                     "***visible***" => $vistem[$message -> {"visible"}],
                                                                     "***sent***"    => $message -> {"sent"} ? $self -> {"template"} -> format_time($message -> {"sent"}) : $self -> build_sent_info($message),
                                                                     "***ops***"     => $self -> {"template"} -> process_template($optems -> {$message -> {"status"}}, {"***id***" => $message -> {"id"}})});
    }

    # If there are no rows, output a "No messages" row
    $rows = $self -> {"template"} -> load_template("messagelist/empty.tem") if(!$rows);

    # Preload the sort templates
    my $sorttems = {};
    foreach my $sorttype ("none", "asc", "desc") {
        $sorttems -> {$sorttype} = $self -> {"template"} -> load_template("messagelist/sort_$sorttype.tem", {"***page***" => $pagenum});
    }

    # Work out the sort controls for each column
    my $sortcols = {};
    foreach my $colname ("status", "subject", "updated", "sent", "visible") {
        if($sort eq $colname) {
            $sortcols -> {$colname} = $self -> {"template"} -> process_template($sorttems -> {$way}, {"***sort***" => $colname});
        } else {
            $sortcols -> {$colname} = $self -> {"template"} -> process_template($sorttems -> {"none"}, {"***sort***" => $colname});
        }
    }

    # Make the state help popup
    my $statepopup = $self -> {"template"} -> load_template("popup.tem", {"***title***"   => $self -> {"template"} -> replace_langvar("MSGLIST_STATE_TITLE"),
                                                                          "***b64body***" => encode_base64($self -> {"template"} -> load_template("messagelist/states.tem"))});

    # Wrap the error up if we have one
    $error = $self -> {"template"} -> load_template("blocks/user_details_error.tem", {"***errors***" => $error})
        if($error);

    # Put the table together
    return $self -> {"template"} -> load_template("messagelist/messagelist.tem", {"***error***"       => $error,
                                                                                  "***info***"        => $info,
                                                                                  "***navigation***"  => $self -> build_navigation($maxpage, $pagenum, $sort, $way), # FIXME: PAGINATION
                                                                                  "***statepopup***"  => $statepopup,
                                                                                  "***sortstate***"   => $sortcols -> {"status"},
                                                                                  "***sortsubject***" => $sortcols -> {"subject"},
                                                                                  "***sortupdated***" => $sortcols -> {"updated"},
                                                                                  "***sortsent***"    => $sortcols -> {"sent"},
                                                                                  "***sortvisible***" => $sortcols -> {"visible"},
                                                                                  "***messages***"    => $rows});
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    # We need to determine what the page title should be, and the content to shove in it...
    my ($title, $content) = ("", "");

    # User must be logged in before we can do anything else
    if($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}) {
        $title    = $self -> {"template"} -> replace_langvar("MSGLIST_TITLE");

        # Get the user's data, as it'll be needed...
        my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($self -> {"session"} -> {"sessuser"});

        my ($userargs, $usererrors);

        # Has the user updated their details?
        if($self -> {"cgi"} -> param("setname")) {
            # Check the details the user submitted, send back the form if they messed up...
            ($userargs, $usererrors) = $self -> validate_userdetails();

            # We need to make sure we have a few values in $userargs, even if validation failed, so add them now
            $userargs -> {"block"}   = $self -> {"block"};
            $userargs -> {"user_id"} = $self -> {"session"} -> {"sessuser"};

            # Did the user mess up their details?
            if($usererrors) {
                $content  = $self -> generate_userdetails_form($userargs, $usererrors);
            } else {
                # Details were valid, update them and then give the user the loggedin form.
                $self -> update_userdetails($userargs);
                $content .= $self -> generate_messagelist();
                $content .= $self -> generate_userdetails_form($userargs, $usererrors);
            }

        # Has the user asked to cancel a message? If so, send the cancel form
        } elsif(defined($self -> {"cgi"} -> {"abortmsg"})) {
            # Check that the message can be cancelled...
            my $message = $self -> check_abort();
            return $message unless(ref($message) eq "HASH");

            $content = $self -> generate_abort_form($message, $self -> get_msglist_args($message -> {"id"}));

        # Has the user confirmed the abort?
        } elsif($self -> {"cgi"} -> param("killmsg")) {
            # Check that the message can be cancelled...
            my $message = $self -> check_abort();
            return $message unless(ref($message) eq "HASH");

            # Okay, we can cancel!
            $self -> set_message_status($message -> {"id"}, "aborted");

            $content = $self -> generate_basic_messagepage($user, $self -> {"template"} -> load_template("messagelist/aborted.tem"));

        # Has the user asked to edit a message? If so, send the message edit form
        } elsif(defined($self -> {"cgi"} -> param("editmsg"))) {
            # Check that the message can be edited...
            my $message = $self -> check_edit();
            return $message unless(ref($message) eq "HASH");

            # If the message is 'pending', switch it to 'incomplete' to make sure it doesn't get sent while the user is editing it!
            $self -> set_message_status($message -> {"id"}, "incomplete") if($message -> {"status"} eq "pending");

            $content = $self -> generate_message_editform($message -> {"id"}, $message, $self -> get_msglist_args($message -> {"id"}));

        # User submitted update, check it and send back the confirm page
        } elsif($self -> {"cgi"} -> param("updatemsg")) {
            # Check that the message can be edited...
            my $message = $self -> check_edit();
            return $message unless(ref($message) eq "HASH");

            # check the form contents...
            my ($args, $form_errors) = $self -> validate_message();

            # If we have errors, send back the edit form...
            if($form_errors) {
                $title   = $self -> {"template"} -> replace_langvar("MESSAGE_EDIT");
                $content = $self -> generate_message_editform($message -> {"id"}, $args, $self -> get_msglist_args($message -> {"id"}), $form_errors);

            # Otherwise, update the message and send back the confirm
            } else {
                # Update the message, note the change to the msgid here!!
                my $msgid = $self -> update_message($message -> {"id"}, $args, $user);

                $title   = $self -> {"template"} -> replace_langvar("MESSAGE_CONFIRM");
                $content = $self -> generate_message_confirmform($msgid, $args, $self -> get_msglist_args($msgid));
            }

        # Has the user confirmed message send?
        } elsif($self -> {"cgi"} -> param("dosend")) {
            # Check that the message can be edited...
            my $message = $self -> check_edit();
            return $message unless(ref($message) eq "HASH");

            # push the message to "pending" and then send it
            $self -> set_message_status($message -> {"id"}, "pending");
            $self -> send_message($message ->{"id"});

            $content = $self -> generate_basic_messagepage($user, $self -> {"template"} -> load_template("messagelist/edited.tem"));

        # Is user forcing a send?
        } elsif(defined($self -> {"cgi"} -> param("sendmsg"))) {
            my $message = $self -> check_send();
            return $message unless(ref($message) eq "HASH");

            # Forcibly send the message...
            $self -> send_message($message ->{"id"}, 1);

            $content = $self -> generate_basic_messagepage($user, $self -> {"template"} -> load_template("messagelist/sent.tem"));

        # Has user selected a message to view?
        } elsif(defined($self -> {"cgi"} -> param("viewmsg"))) {
            # Check that the message can be cancelled...
            my $message = $self -> check_abort();
            return $message unless(ref($message) eq "HASH");

            $content = $self -> generate_view_form($message, $self -> get_msglist_args($message -> {"id"}));

        # No recognised operations in progress - send the basic list and user details box
        } else {
            $content = $self -> generate_basic_messagepage($user);
        }

    # User has not logged in, force them to
    } else {
        my $url = "index.cgi?block=".$self -> {"module"} -> get_block_id('login')."&amp;back=".$self -> {"session"} -> encode_querystring($self -> {"cgi"} -> query_string());

        print $self -> {"cgi"} -> redirect($url);
        exit;
    }

    # Done generating the page content, return the filled in page template
    return $self -> {"template"} -> load_template("page.tem", {"***title***"     => $title,
                                                               "***topright***"  => $self -> generate_topright(),
                                                               "***extrahead***" => "",
                                                               "***content***"   => $content});

}


1;
