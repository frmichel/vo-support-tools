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
// This script requests the creation of trends and alert histograms for all SEs supporting biomed, for 3 types of probes:
// org.sam.SRM-Put-biomed, org.sam.SRM-GetSURLs-biomed, org.sam.SRM-GetTURLs-biomed.
// Usage: http://hostname/check-all-se-3probes.php?nbDays=7
// Parameters:
//    nbDays = period of time (in days) that the report will cover. Defaults to 31.
//    page = number of the page to be displayed (defaults to 1)
//    withTrend = open the trends report of Nagios
//    withHistogram = open the alert histogram report of Nagios
//
// Author: Franck MICHEL, CNRS, I3S lab. fmichel[at]i3s[dot]unice[dot]fr
//---------------------------------------------------------------------------------

// Check parameters validity
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
setcookie("withTrendAll3Probes", $withTrend, time()+31536000, "/");
setcookie("withHistogramAll3Probes", $withHistogram, time()+31536000, "/");

// Time: report from (today - n) days at midnight until today at 23:59:59, 
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
$root_url_alerts = "https://grid04.lal.in2p3.fr/nagios/cgi-bin/histogram.cgi?createimage&assumestateretention=yes&initialstateslogged=no&graphevents=120&newstatesonly=no&graphstatetypes=3";
$root_url_alerts .= "&timeperiod=".$timeperiod;
$root_url_alerts .= "&breakdown=".$breakdown;
$root_url_alerts .= "&t1=".$t1;
$root_url_alerts .= "&t2=".$t2;

?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="fr">
<head>
	<title>	
		Service report for all SEs during the last <?php print $nbDays; ?> days - page <?php print $page; ?>
	</title>
	<link href="styles.css" rel="stylesheet" type="text/css">
	<meta name="robots" content="noindex">
</head>

<body>
	<h2>Service report for all SEs during the last <?php print $nbDays; ?> days - page <?php print $page; ?></h2>

	<!-- Navigation links --> 
	<?php if ($nbPage > 1 ) { ?>
		<p class="paging">
		<?php if ($page > 1) { ?>
			<a href="<?php print $_SERVER['SCRIPT_NAME']."?nbDays=".$nbDays."&withTrend=".$withTrend."&withHistogram=".$withHistogram."&page=".($page-1); ?>"> << Page <?php print ($page-1)."/".$nbPage; ?></a>&nbsp;|&nbsp;
		<?php } ?>
		<?php if ($page < $nbPage) { ?>
			<a href="<?php print $_SERVER['SCRIPT_NAME']."?nbDays=".$nbDays."&withTrend=".$withTrend."&withHistogram=".$withHistogram."&page=".($page+1); ?>"> Page <?php print ($page+1)."/".$nbPage; ?> >></a>
		<?php } ?>
		</p>
	<?php } ?>

	<?php foreach ($list_se_by_page[$page - 1] as $host) { ?>
		<div class="section_separator">
			<a href="<?php print "check-single-se.php?nbDays=".$nbDays."&hostname=".$host."&withTrend=".$withTrend."&withHistogram=".$withHistogram; ?>"" target="_blank">
				Host <?php print $host; ?>
			</a>
		</div>
		
		<?php if ($withTrend=="on" ) { ?>
		<div class="graphx3">
		<img src="<?php 
			$url = $root_url_trends;
			$url .= "&host=".$host;
			$url .= "&service=org.sam.SRM-Put-biomed";
			print $url;
		?>" name="alert_<?php print $host; ?>" border="0">
		</div>
		<div class="graphx3">
		<img src="<?php 
			$url = $root_url_trends;
			$url .= "&host=".$host;
			$url .= "&service=org.sam.SRM-GetSURLs-biomed";
			print $url;
		?>" name="alert_<?php print $host; ?>" border="0">
		</div>
		<div class="graphx3">
		<img src="<?php 
			$url = $root_url_trends;
			$url .= "&host=".$host;
			$url .= "&service=org.sam.SRM-GetTURLs-biomed";
			print $url;
		?>" name="alert_<?php print $host; ?>" border="0">
		</div>
		<?php } ?>

		<?php if ($withHistogram=="on" ) { ?>
		<div class="graphx3">
		<img src="<?php 
			$url = $root_url_alerts;
			$url .= "&host=".$host;
			$url .= "&service=org.sam.SRM-Put-biomed";
			print $url;
		?>" name="alert_<?php print $host; ?>" border="0">
		</div>
		<div class="graphx3">
		<img src="<?php 
			$url = $root_url_alerts;
			$url .= "&host=".$host;
			$url .= "&service=org.sam.SRM-GetSURLs-biomed";
			print $url;
		?>" name="alert_<?php print $host; ?>" border="0">
		</div>
		<div class="graphx3">
		<img src="<?php 
			$url = $root_url_alerts;
			$url .= "&host=".$host;
			$url .= "&service=org.sam.SRM-GetTURLs-biomed";
			print $url;
		?>" name="alert_<?php print $host; ?>" border="0">
		</div>
		<?php } ?>

	<?php } ?>

	<!-- Navigation links --> 
	<?php if ($nbPage > 1 ) { ?>
		<p class="paging">
		<?php if ($page > 1) { ?>
			<a href="<?php print $_SERVER['SCRIPT_NAME']."?nbDays=".$nbDays."&withTrend=".$withTrend."&withHistogram=".$withHistogram."&page=".($page-1); ?>"> << Page <?php print ($page-1)."/".$nbPage; ?></a>&nbsp;|&nbsp;
		<?php } ?>
		<?php if ($page < $nbPage) { ?>
			<a href="<?php print $_SERVER['SCRIPT_NAME']."?nbDays=".$nbDays."&withTrend=".$withTrend."&withHistogram=".$withHistogram."&page=".($page+1); ?>"> Page <?php print ($page+1)."/".$nbPage; ?> >></a>
		<?php } ?>
		</p>
	<?php } ?>
	
</body>
</html>
