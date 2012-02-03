<?php

if(!defined('ANNOUNCEMENTS')) {
    exit;
}

/** A class to write announcements to the generated page.
 *
 *
 * @author Chris Page
 * @date 21 Nov 2011
 */
class AnnouncementWriter
{
    private $truncate;
    private $timefmt;

    /** Create a new AnnouncementWriter, optionally setting the truncation length and time format.
     *
     * @param $truncate Integer: The number of characters at which the announcement should
     *                  be truncated and given a "show more" option).
     * @param $timefmt  String: A string passed to date when formatting timestamps for printing.
     */
    function __construct($truncate = 300, $timefmt = "jS F Y")
    {
        $this -> truncate = $truncate;
        $this -> timefmt  = $timefmt;
    }


    /** Write announcements to the output. This will print the contents of any announcements
     * specified to the page. Wherever possible, this has been written to try and reproduce
     * Iain's layout and colour scheme.
     *
     * @param Array: An array of announcements to print to the page.
     */
    public function display_announcements($announcements)
    {
        // Do nothing if there are no announcements to display
        if(!count($announcements)) {
            echo "<ul><li>There are currently no announcements.</li></ul>";
            return;
        }

        foreach($announcements as $entry) {
            echo "<div style=\"background-color: #F0F0F0; border: solid 1px #F0F0F0; margin-bottom: 3px;\">";
            echo "<div style=\"margin: 15px;\">";
            echo "<p>";

            // Subject is enforced by Megaphone.
            echo "<h4 style=\"display: inline;\">".$entry['subject']."</h4>";

            if(!empty($entry['announce_link']) && !$entry['show_link']) {
                echo "&nbsp;<span style=\"font-size: smaller;\">(<a href=\"".$entry['announce_link']."\">link</a>)</span>";
            }

            echo "<span style=\"float : right; font-size : smaller;\">";
            echo "(".date($this -> timefmt, $entry['sent']).$this -> make_signature($entry['realname'], $entry['email']).")";
            echo "</span>";
            if(!empty($entry['announce_link']) && $entry['show_link']) {
                echo "<div style=\"font-size: smaller; padding-left: 2em;\">(<a href=\"".$entry['announce_link']."\">".$entry['announce_link']."</a>)</div>";
            }
            echo "</p>";

            // Message is also enforced by megaphone
            echo $this -> make_brief_message($entry['message'], $entry['message_id']);
            echo $this -> make_full_message($entry['message'], $entry['message_id']);

            if(!empty($entry['close_date']) && $entry['show_close']) {
                echo "<p><span style=\"font-size: smaller;\">Closing date:".date($this -> timefmt, $entry['close_date'])."</span></p>";
            }
            print "</div></div>";
        } // foreach($announcements as $entry)
    }


    /** Generate a 'signature' to show in the announcment. This builds a signature (really
     * just a name and email) to show in the announcement to attribute it. Both arguments
     * are required, and taken from the user's Megaphone profile.
     *
     * @param $name  String: the name of the user who posted the announcement.
     * @param $email String: the user's email address.
     * @return String: the signature to show in the announcement.
     */
    private function make_signature($name, $email)
    {
        return "<span style=\"color: #808080; font-size: smaller;\"> ~ by <a href=\"mailto:$email\">$name</a></span>";
    }


    /** Generate a string containing the short version of the announcement. This
     * will generate a block of html containing the message, optionally including
     * a 'show more' option if the messages is longer than the truncation level.
     *
     * @param $message String: The message to show. Must be already escaped for html,
     *                 but newlines will be converted to br.
     * @param id       Integer: The message id.
     * @return String: a string containing the message block.
     */
    private function make_brief_message($message, $id)
    {
        $truncated = false;

        // Truncate the message if needed
        if(strlen($message) > $this -> truncate) {
            $message = substr($message, 0, $this -> truncate);
            $message = substr($message, 0, strrpos($message, " "));
            $truncated = true;
        }

        $brief  = "<p style=\"display: block;\" id=\"messagebrief-$id\">";
        $brief .= nl2br($message);

        if($truncated) {
            $brief .= "&nbsp;<span style=\"font-size: smaller;\">";
            $brief .= "[<a onclick=\"document.getElementById('messagebrief-$id').style.display = 'none';";
            $brief .= "document.getElementById('messagefull-$id').style.display = 'block';\">show more</a>]";
            $brief .= "</span>";
        }
        $brief .= "</p>";

        return $brief;
    }


    /** Generate the full message block. If the message has been truncated, this will
     * generate a block of html containing the full message, and a link to hide the
     * full message and show the short version. If the message was not truncated, this
     * will return an empty string.
     *
     * @param $message String: The message to show. Must be already escaped for html,
     *                 but newlines will be converted to br.
     * @param id       Integer: The message id.
     * @return String: a string containing the message block.
     */
    private function make_full_message($message, $id)
    {
        $full = "";

        // Only generate anything if the message has been truncated in the brief block
        if(strlen($message) > $this -> truncate) {
            $full .= "<p style=\"display: none;\" id=\"messagefull-$id\">";
            $full .= nl2br($message);

            $full .= "&nbsp;<span style=\"font-size: smaller;\">";
            $full .= "[<a onclick=\"document.getElementById('messagebrief-$id').style.display = 'block';";
            $full .= "document.getElementById('messagefull-$id').style.display = 'none';\">show less</a>]";
            $full .= "</span>";
            $full .= "</p>";
        }

        return $full;
    }

}