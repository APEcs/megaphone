<?php

if(!defined('ANNOUNCEMENTS')) {
    exit;
}

/** A class to encapsulate the retrieval of annoucements from the Megaphone database.
 * This class provides the functions needed to communicate with a Megaphone database
 * in order to obtain any currently visible open announcements.
 *
 * @author Chris Page
 * @date 21 Nov 2011
 */
class AnnouncementDatabase
{
    private $database;

    /** Connect to the Megaphone database. This function relies on globals defined in
     * AnnounceSettings.php - ensure that the settings have been loaded before calling
     * this function!
     */
    public function connect() {
        global $agDBserver, $agDBdatabase, $agDBusername, $agDBpassword;

        $this -> database = new mysqli($agDBserver, $agDBusername, $agDBpassword, $agDBdatabase);
        if(mysqli_connect_error()) {
            die('Connect Error ('.mysqli_connect_errno().') '.mysqli_connect_error());
        }
    }

    /** Release the connection to the Megaphone database.
     */
    public function disconnect() {
        $this -> database -> close();
    }

    /** Obtain an array of currently open announcements from the Megaphone database.
     *
     * @param $categories Array: the names of categories to obtain announcments for.
     * @param $order      String: the requested ordering. May be "deadline", "submission". If
     *                    omitted, defaults to "submission".
     * @param $showfuture Show announcements that haven't opened yet (ie: the announcement is
     *                    'visible' as far as Megaphone is concerned, but it has an open date
     *                    in the future.
     * @return Array: an array of database records, one for each announcement, or an empty
     *         array if there are no annoucements to show.
     */
    public function get_announcements($categories, $order = NULL, $showfuture = false) {

        // Do nothing if the caller hasn't specified any categories to select
        if(count($categories) == 0) return;

        // Convert the specified categories to a string to use the there WHERE clause,
        // with category names replaced with category id numbers.
        $cat_where = "(";
        for($pos = 0; $pos < count($categories); ++$pos) {
            if($id = $this -> get_categoryid($categories[$pos])) {
                if($pos > 0) $cat_where .= " OR ";
                $cat_where .= "mc.cat_id = $id";
            }
        }
        $cat_where .= ")";

        $sqlquery = "SELECT DISTINCT m.*,md.*,u.*
                     FROM mp_messages_announcecats AS mc, mp_messages_announcedata AS md, mp_messages AS m, mp_users AS u
                     WHERE $cat_where
                     AND m.id = mc.message_id
                     AND md.message_id = mc.message_id
                     AND u.user_id = m.user_id
                     AND m.visible = 1
                     AND m.status = 'sent'
                     AND (md.close_date IS NULL OR md.close_date > UNIX_TIMESTAMP())";

        // If future announcements are not enabled, only open announcements should appear
        if(!$showfuture) $sqlquery .= " AND (md.open_date IS NULL OR md.open_date <= UNIX_TIMESTAMP())";

        // Ordering control...
        if($order == "deadline") {
            $sqlquery .= " ORDER BY md.close_date ASC";
        } else {
            $sqlquery .= " ORDER BY m.sent DESC";
        }

        // Fetch all the results from the database. This /could/ be done with a single
        // mysqli_result::fetch_all(), except that it needs to work with a practically
        // Silurian version of php.
        $records = array();
        if($result = $this -> database -> query($sqlquery)) {
            while($row = $result -> fetch_assoc()) {
                $records[] = $row;
            }
        }

        return $records;
    }


    /** Obtain the ID number for the specified category. This looks up the specified
     *  category in the database, and returhs the ID number associated with it.
     *
     * @param caregory The name of the category to look up.
     * @return The category ID number, or NULL if the category can not be found.
     */
    protected function get_categoryid($category)
    {
        // Escape the category, and make sure _ and % are handled too...
        $category = addcslashes($this -> database -> real_escape_string($category), '_%');

        $sqlquery = "SELECT id FROM mp_announce_categories
                     WHERE category LIKE '$category'";

        $catid = NULL;
        // Do the category lookup, and store the id if the query works.
        if($result = $this -> database -> query($sqlquery)) {
            if($data = $result -> fetch_row()) {
                $catid = $data[0];
            }
            $result -> free_result();
        }

        return $catid;
    }

}

?>