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
// This script request the creation of trends and alert histograms for all SEs supporting biomed
// Usage: http://hostname/check-all-se.php?nbDays=7&service=put
// Parameters:
//    nbDays = period of time (in days) that the report will cover. Defaults to 31.
//    service = service tested: one of {put, getsurl, getturl, get}. Defaults to put.
//      - put: service org.sam.SRM-Put-biomed, 
//      - getsurl: service org.sam.SRM-GetSURLs-biomed,
//      - getturl: service org.sam.SRM-GetTURLs-biomed
//      - get: service org.sam.SRM-Get-biomed
//    withTrend = open the trends report of Nagios
//    withHistogram = open the alert histogram report of Nagios
//    page = number of the page to be displayed (defaults to 1)
//
// Author: Franck MICHEL, CNRS, I3S lab. fmichel[at]i3s[dot]unice[dot]fr
//---------------------------------------------------------------------------------

// Check parameters validity
if (array_key_exists("service", $_GET))
	$service = $_GET['service'];
else
	$service = "";
switch ($service) {
	case "put":
		$service="org.sam.SRM-Put-biomed";
		break;
	case "getsurl":
		$service="org.sam.SRM-GetSURLs-biomed";
		break;
	case "getturl":
		$service="org.sam.SRM-GetTURLs-biomed";
		break;
	case "get":
		$service="org.sam.SRM-Get-biomed";
		break;
	default:
		$service="org.sam.SRM-Put-biomed";
}

if (array_key_exists("nbDays", $_GET))
	$nbDays = $_GET['nbDays'];
else
	$nbDays = 31;

if (array_key_exists("page", $_GET)) {
	$page = $_GET['page'];
	if ($page > count($list_se_by_page))
		$page = 1;
} else
	$page = 1;

if (array_key_exists("withTrend", $_GET))
	$withTrend = $_GET['withTrend'];
else
	$withTrend = "off";

if (array_key_exists("withHistogram", $_GET))
	$withHistogram = $_GET['withHistogram'];
else
	$withHistogram = "off";


// Set values into cookie for next time
setcookie("withTrendAll", $withTrend, time()+31536000, "/");
setcookie("withHistogramAll", $withHistogram, time()+31536000, "/");

// Report from today - n days at midnight until today 23:59:59, 
// in order to avoid generating a new report each time the page is refreshed
date_default_timezone_set("Europe/Paris");
$end_of_today = mktime(23, 59, 59);
$t1= $end_of_today;
$t2= $end_of_today - ($nbDays * 24 * 60 * 60) + 1;

// Prepare the Trends histogram url
$root_url_trends = "https://grid04.lal.in2p3.fr/nagios/cgi-bin/trends.cgi?createimage&assumeinitialstates=yes&assumestatesduringnotrunning=yes&initialassumedhoststate=0&initialassumedservicestate=0&assumestateretention=no&includesoftstates=yes&backtrack=4&zoom=4";
$root_url_trends .= "&t1=".$t1;
$root_url_trends .= "&t2=".$t2;


// Check duration to get best breakdown of the alerts histogram
if ($nbDays <= 7) {
	$timeperiod="last7days";
	$breakdown="dayofweek";
} else if ($nbDays <= 31) {
	$timeperiod="last31days";
	$breakdown="dayofmonth";
} else {
	$timeperiod="thisyear";
	$breakdown="monthly";
}

// Prepare the Alerts histogram url
$root_url_alert = "https://grid04.lal.in2p3.fr/nagios/cgi-bin/histogram.cgi?createimage&assumestateretention=yes&initialstateslogged=no&graphevents=120&newstatesonly=no&graphstatetypes=3";
$root_url_alert .= "&timeperiod=".$timeperiod;
$root_url_alert .= "&breakdown=".$breakdown;
$root_url_alert .= "&t1=".$t1;
$root_url_alert .= "&t2=".$t2;


?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="fr">
<head>
	<title>	
		Service report for all SEs during the last <?php print $nbDays; ?> days - page <?php print $page; ?> - Probe <?php print $service; ?>
	</title>
	<link href="styles.css" rel="stylesheet" type="text/css">
	<meta name="robots" content="noindex">
</head>

<body>
	<h2>Service report for all SEs during the last <?php print $nbDays; ?> days - page <?php print $page; ?></h2>
	<h3>Probe <?php print $service; ?></h3>

	<!-- Navigation links --> 
	<?php if ($nbPage > 1 ) { ?>
		<p class="paging">
		<?php if ($page > 1) { ?>
			<a href="<?php print $_SERVER['SCRIPT_NAME']."?nbDays=".$nbDays."&service=".$service."&withTrend=".$withTrend."&withHistogram=".$withHistogram."&page=".($page-1); ?>"> << Page <?php print ($page-1)."/".$nbPage; ?></a>&nbsp;|&nbsp;
		<?php } ?>
		<?php if ($page < $nbPage) { ?>
			<a href="<?php print $_SERVER['SCRIPT_NAME']."?nbDays=".$nbDays."&service=".$service."&withTrend=".$withTrend."&withHistogram=".$withHistogram."&page=".($page+1); ?>"> Page <?php print ($page+1)."/".$nbPage; ?> >></a>
		<?php } ?>
		</p>
	<?php } ?>


	<?php 
		if ($withTrend=="on" && $withHistogram=="on") 
			$display_style="graphx2";
		else 
			$display_style="graphx1";				
	?>

	<?php foreach ($list_se_by_page[$page - 1] as $host) { ?>
	<div class="section_separator">
		<a href="<?php print "check-single-se.php?nbDays=".$nbDays."&hostname=".$host."&withTrend=".$withTrend."&withHistogram=".$withHistogram; ?>"" target="_blank">
			Host <?php print $host; ?>
		</a>
	</div>

		<?php if ($withTrend=="on" ) { ?>
		<div class="<?php print $display_style; ?>">
			<img src="<?php
				$url = $root_url_trends;
				$url .= "&host=".$host;
				$url .= "&service=".$service;
				print $url;
			?>" name="trendsimage_<?php print $host; ?>" border="0">
		</div>
		<?php } ?>
	
		<?php if ($withHistogram=="on" ) { ?>
		<div class="<?php print $display_style; ?>">
			<img src="<?php 
				$url = $root_url_alert;
				$url .= "&host=".$host;
				$url .= "&service=".$service;
				print $url;
			?>" name="alert_<?php print $host; ?>" border="0">
		</div>
		<?php } ?>
	<?php } ?>
	
	
	<!-- Navigation links --> 
	<?php if ($nbPage > 1 ) { ?>
		<p class="paging">
		<?php if ($page > 1) { ?>
			<a href="<?php print $_SERVER['SCRIPT_NAME']."?nbDays=".$nbDays."&service=".$service."&withTrend=".$withTrend."&withHistogram=".$withHistogram."&page=".($page-1); ?>"> << Page <?php print ($page-1)."/".$nbPage; ?></a>&nbsp;|&nbsp;
		<?php } ?>
		<?php if ($page < $nbPage) { ?>
			<a href="<?php print $_SERVER['SCRIPT_NAME']."?nbDays=".$nbDays."&service=".$service."&withTrend=".$withTrend."&withHistogram=".$withHistogram."&page=".($page+1); ?>"> Page <?php print ($page+1)."/".$nbPage; ?> >></a>
		<?php } ?>
		</p>
	<?php } ?>
	
</body>
</html>
