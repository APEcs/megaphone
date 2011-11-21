<?php

// Load the startup code and configuration
$preIP = dirname(__FILE__);
require_once("$preIP/includes/WebStart.php");
require_once("$preIP/includes/AnnouncementDatabase.php");
require_once("$preIP/includes/AnnouncementWriter.php");

/** A class to handle Announcement requests. This class allows categories
 * of announcements to be written to pages as needed. To use it, you can
 * use the following code:
 *
 * @verbatim
 * require_once("/path/to/this/AnnouncementHandler.php");
 * $handler = new AnnouncementHandler();
 * $handler -&gt; displayPublicAnnouncements("UGT");
 * @endverbatim
 *
 * This class has been designed to emulate Iain's announcement system as
 * closely as possible. It should be noted that some features are not
 * present in this class:
 *
 * - no support for announcement creation/deletion is provided. These tasks
 *   are performed via the Megaphone interface rather than this class.
 * - this does not include the "displayPublicCareersAdvertisements()" function,
 *   as careers stuff is currently handled via moodle.
 *
 * @author Chris Page
 * @date 21 Nov 2011
 */
class AnnouncementHandler
{
    private $database;
    private $writer;

    function __construct()
    {
        $this -> database = new AnnouncementDatabase();
        $this -> writer   = new AnnouncementWriter();
    }

    /** Output any announcements currently open in the specified category.
     *
     * @param $category String: The category to output announcements for.
     */
    public function displayPublicAnnouncements($category)
    {
        $this -> database -> connect();
        $this -> writer -> display_announcements($this -> database -> get_announcements($this -> category_map($category)));
        $this -> database -> disconnect();
    }

    /** Convert a category name to an array of categories. This allows the
     * caller to specify a single category, and potentially get several
     * categories in return (for example, 'Students_all" will result in
     * "UGT, PGT, PGR".
     *
     * @param $category String: The category to convert.
     * @return Array: An array of categories to look up.
     */
    private function category_map($category)
    {
        $categorymap = array();

        if($category == "UGT") {
            $categorymap[] = "UGT";
        } else if($category == "PGT") {
            $categorymap[] = "PGT";
        } else if($category == "PGR") {
            $categorymap[] = "PGR";
        } else if($category == "Staff") {
            $categorymap[] = "Staff";
        } else if($category == "Students_all") {
            $categroymap[] = "UGT";
            $categorymap[] = "PGT";
            $categorymap[] = "PGR";
        } else if($category == "Students_taught") {
            $categroymap[] = "UGT";
            $categorymap[] = "PGT";
        } else if($category == "All") {
            $categroymap[] = "UGT";
            $categorymap[] = "PGT";
            $categorymap[] = "PGR";
            $categorymap[] = "Staff";
        } else {
            $categorymap[] = $category;
        }

        return $categorymap;
    }
}

?>