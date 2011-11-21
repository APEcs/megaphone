<?php

/** Do initial setup for a web request. This does security checks, and the loads the config.
 * This is based on MediaWiki's script of the same name.
 *
 * @file
 */

// Protect against register_globals
// This must be done before any globals are set by the code
if ( ini_get( 'register_globals' ) ) {
    if ( isset( $_REQUEST['GLOBALS'] ) ) {
        die( '<a href="http://www.hardened-php.net/globals-problem">$GLOBALS overwrite vulnerability</a>');
    }
    $verboten = array(
        'GLOBALS',
        '_SERVER',
        'HTTP_SERVER_VARS',
        '_GET',
        'HTTP_GET_VARS',
        '_POST',
        'HTTP_POST_VARS',
        '_COOKIE',
        'HTTP_COOKIE_VARS',
        '_FILES',
        'HTTP_POST_FILES',
        '_ENV',
        'HTTP_ENV_VARS',
        '_REQUEST',
        '_SESSION',
        'HTTP_SESSION_VARS'
    );
    foreach ( $_REQUEST as $name => $value ) {
        if( in_array( $name, $verboten ) ) {
            header( "HTTP/1.1 500 Internal Server Error" );
            echo "register_globals security paranoia: trying to overwrite superglobals, aborting.";
            die( -1 );
        }
        unset( $GLOBALS[$name] );
    }
}

// Allow other files to actually load now
define('ANNOUNCEMENTS', true);

// Work out where we are
$IP = dirname(__FILE__);

require_once("$IP/AnnouncementSettings.php");
?>