<?php
include("globals.php");
logAccess();
if (isHacker()) {
?>
<body>
<h1>Your hacking attempt is being blocked. Your address is logged.</h1>
</body>
<?php exit(0);
}

//---------------------------------------------------------------------------------
// This script submits a request to the GOCDB to search for the hostname of a SE supported by biomed
// Parameters:
//    hostname = the hostname to search for
//
// Author: Franck MICHEL, CNRS, I3S lab. fmichel[at]i3s[dot]unice[dot]fr
//---------------------------------------------------------------------------------

 if (array_key_exists("hostname", $_GET)) {
	$hostname = $_GET['hostname'];
	if ($hostname == "")
		$error = "Parameter error: SE hostname parameter is mandatory.";
	else if (! in_array($hostname, $list_se)) {
		$error = "WARNING: SE ".$hostname." does not support the Biomed VO.";
	}
} else {
	$error = "Parameter error: SE hostname parameter is mandatory.";
	$hostname = "";
}

// Errors management
if (isset($error)) {
	?>
	<html>
	<head>
		<title>GOCDB search - error</title>
		<link href="styles.css" rel="stylesheet" type="text/css">
	</head>
	<body>
	<h2>GOCDB search - error</h2>
	<div class="error"><?php print $error; ?></div>
	</body>
	</html>
	<?php
	exit(0);
}

?>
<html>
<head>
	<meta name="robots" content="noindex">
</head>
<body onLoad="document.formGOCDBSearch.submit()">

	<form name="formGOCDBSearch" action="https://goc.egi.eu/portal/index.php?Page_Type=Submit_Search" method="post">
		<input name="Search_String" type="hidden" value="<?php print($hostname); ?>" />
	</form>

</body> 