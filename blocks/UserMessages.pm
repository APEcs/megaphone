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
                              "desc" => \&sortfn_sent_desc}
              };

# ============================================================================
#  Content generation functions

sub generate_messagelist {
    my $self  = shift;
    my $error = shift;

    # First stage; we need to get a list of the user's messages. All of them.
    # We can't rely on SQL LIMIT and ORDER BY to get it right, unfortunately. 
    my $messh = $self -> {"dbh"} -> prepare("SELECT id, status, subject, updated, sent
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
    my $maxpage = int(scalar(@sorted) / $self -> {"settings"} -> {"config"} -> {"UserMessages:pagelength"});
    
    # And which page the user is looking at
    my $pagenum   = is_defined_numeric($self -> {"cgi"}, "page") || 0;                                                                                                               
    $pagenum = 0        if($pagenum < 0);
    $pagenum = $maxpage if($pagenum > $maxpage);

    # Get the splice. Probably a nicer way to do this, but hell, it works.
    my @spliced = splice(@sorted, $pagenum * $self -> {"settings"} -> {"config"} -> {"UserMessages:pagelength"}, $self -> {"settings"} -> {"config"} -> {"UserMessages:pagelength"});
    
    # Precache the row template to speed things up
    my $rowtem = $self -> {"template"} -> load_template("blocks/messagelist_row.tem", {"***sort***" => $sort,
                                                                                       "***way***"  => $way,
                                                                                       "***page***" => $pagenum});
    # Precache the ops templates for each status
    my $optems = {};
    foreach my $state (keys(%{$stateweight})) {
        $optems -> {$state} = $self -> {"template"} -> load_template("blocks/messagelist_op$state.tem", {"***sort***" => $sort,
                                                                                                          "***way***"  => $way,
                                                                                                          "***page***" => $pagenum});
    }

    # Process the rows...
    my $rows = "";
    foreach my $message (@spliced) {
        $rows .= $self -> {"template"} -> process_template($rowtem, {"***id***"      => $message -> {"id"},
                                                                     "***status***"  => $message -> {"status"},
                                                                     "***subject***" => $message -> {"subject"},
                                                                     "***updated***" => $self -> {"template"} -> format_time($message -> {"updated"}),
                                                                     "***sent***"    => $message -> {"sent"} ? $self -> {"template"} -> format_time($message -> {"sent"}) : $self -> {"template"} -> replace_langvar("MSGLIST_NOTSENT"),
                                                                     "***ops***"     => $self -> {"template"} -> process_template($optems -> {$message -> {"status"}}, {"***id***" => $message -> {"id"}})});
    }

    # Preload the sort templates
    my $sorttems = {};
    foreach my $sorttype ("none", "asc", "desc") {
        $sorttems -> {$sorttype} = $self -> {"template"} -> load_template("blocks/messagelist_sort_$sorttype.tem", {"***page***" => $pagenum});
    }

    # Work out the sort controls for each column
    my $sortcols = {};
    foreach my $colname ("state", "subject", "updated", "sent") {
        if($sort eq $colname) {
            $sortcols -> {$colname} = $self -> {"template"} -> process_template($sorttems -> {$way}, {"***sort***" => $colname});
        } else {
            $sortcols -> {$colname} = $self -> {"template"} -> process_template($sorttems -> {"none"}, {"***sort***" => $colname});
        }
    }

    # Make the state help popup
    my $statepopup = $self -> {"template"} -> load_template("popup.tem", {"***title***"   => $self -> {"template"} -> replace_langvar("MSGLIST_STATE_TITLE"),
                                                                          "***b64body***" => encode_base64($self -> {"template"} -> load_template("blocks/messagelist_states.tem"))});

    # Wrap the error up if we have one
    $error = $self -> {"template"} -> load_template("blocks/user_details_error.tem", {"***errors***" => $error})
        if($error);

    # Put the table together
    return $self -> {"template"} -> load_template("blocks/messagelist.tem", {"***error***"       => $error,
                                                                             "***naviation***"   => "", # FIXME: PAGINATION
                                                                             "***statepopup***"  => $statepopup,
                                                                             "***sortstate***"   => $sortcols -> {"state"},
                                                                             "***sortsubject***" => $sortcols -> {"subject"},
                                                                             "***sortupdated***" => $sortcols -> {"updated"},
                                                                             "***sortsent***"    => $sortcols -> {"sent"},
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
        $content .= $self -> generate_messagelist();

        # Get the user's data, as it'll be needed...
        my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($self -> {"session"} -> {"sessuser"});

        my ($userargs, $usererrors);

        # Has the user updated their details?
        if($self -> {"cgi"} -> param("setname")) {
            # Check the details the user submitted, send back the form if they messed up...
            ($userargs, $usererrors) = $self -> validate_userdetails();

            # We need to make sure we have a few values in $args, even if validation failed, so add them now
            $userargs -> {"block"}   = $self -> {"block"};
            $userargs -> {"user_id"} = $self -> {"session"} -> {"sessuser"};

            # Did the user mess up their details?
            if($usererrors) {
                $content  = $self -> generate_userdetails_form($userargs, $usererrors);
            } else {
                # Details were valid, update them and then give the user the loggedin form.
                $self -> update_userdetails($userargs);
                $content  .= $self -> generate_userdetails_form($userargs, $usererrors);
            }

        # No recognised operations in progress - send the basic list and user details box
        } else {
            $userargs = {"realname" => $user -> {"realname"},
                         "rolename" => $user -> {"rolename"},
                         "block"    => $self -> {"block"}};
            $title    = $self -> {"template"} -> replace_langvar("MSGLIST_TITLE");
            $content .= $self -> generate_userdetails_form($userargs, $usererrors);
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
