<?php 
include("globals.php");
logAccess();
if (isHacker()) {
?>
<body>
<h1>Your hacking attempt has been blocked. Your address is logged.</h1>
</body>
<?php exit(0);
}

//---------------------------------------------------------------------------------
// This script requests the creation of Nagios trends and histograms repots for 3 types of services 
// of the specified SE, for the specified time range. It can also open search pages on GGUS and GOCDB for that SE.
// Services: org.sam.SRM-Put-biomed, org.sam.SRM-GetSURLs-biomed, org.sam.SRM-GetTURLs-biomed, org.sam.SRM-Get-biomed
// Usage: http://localhost/check-single-se.php?nbDays=7&hostname=grid-se.ii.edu.mk
// Parameters:
//    nbDays = period of time (in days) that the report will cover. Defaults to 31.
//    hostname = the hostname of the SE to check
//    withTrend = open the trends report of Nagios
//    withHistogram = open the alert histogram report of Nagios
//    withGGUSsearch = search for GGUS open tickets related to that SE
//    withGOCDBsearch = search for GOCDB info related to that SE
//
// Author: Franck MICHEL, CNRS, I3S lab. fmichel[at]i3s[dot]unice[dot]fr
//---------------------------------------------------------------------------------

// Check parameters validity
if (array_key_exists("nbDays", $_GET))
	$nbDays = $_GET['nbDays'];
else
	$nbDays = 7;

if (array_key_exists("withTrend", $_GET))
	$withTrend = $_GET['withTrend'];
else
	$withTrend = "off";

if (array_key_exists("withHistogram", $_GET))
	$withHistogram = $_GET['withHistogram'];
else
	$withHistogram = "off";

if (array_key_exists("withGGUSsearch", $_GET))
	$withGGUSsearch = $_GET['withGGUSsearch'];
else
	$withGGUSsearch = "off";

if (array_key_exists("withGOCDBsearch", $_GET))
	$withGOCDBsearch = $_GET['withGOCDBsearch'];
else
	$withGOCDBsearch = "off";

	if (array_key_exists("hostname", $_GET)) {
	$hostname = $_GET['hostname'];	

	if ($hostname == "")
		$error = "Parameter error: SE hostname parameter is mandatory.";
	else if (! in_array($hostname, $list_se)) {
	
		$error = "WARNING: SE ".$hostname." does not support the Biomed VO, the reports may fail.";
	}
} else {
	$error = "Parameter error: SE hostname parameter is mandatory.";
	$hostname = "";
}

// Set values into cookie for next time
setcookie("withTrendSingle", $withTrend, time()+31536000, "/");
setcookie("withHistogramSingle", $withHistogram, time()+31536000, "/");
setcookie("withGGUSsearchSingle", $withGGUSsearch, time()+31536000, "/");
setcookie("withGOCDBsearchSingle", $withGOCDBsearch, time()+31536000, "/");
setcookie("hostname", $hostname, time()+31536000, "/");
	
// Time: report from (today - n) days at midnight until today at 23:59:59, 
// in order to avoid generating a new report each time the page is refreshed
date_default_timezone_set("Europe/Paris");
$end_of_today = mktime(23, 59, 59);
$t1= $end_of_today;
$t2= $end_of_today - ($nbDays * 24 * 60 * 60) + 1;

//--- Prepare URL for trends report
$url_trends = "https://grid04.lal.in2p3.fr/nagios/cgi-bin/trends.cgi?createimage&assumeinitialstates=yes&assumestatesduringnotrunning=yes&initialassumedhoststate=0&initialassumedservicestate=0&assumestateretention=no&includesoftstates=yes&backtrack=4&zoom=4";
$url_trends .= "&t1=".$t1;
$url_trends .= "&t2=".$t2;
$url_trends .= "&host=".$hostname;

// Check duration to get best breakdown
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

$url_histogram = "https://grid04.lal.in2p3.fr/nagios/cgi-bin/histogram.cgi?createimage&assumestateretention=yes&initialstateslogged=no&graphevents=120&newstatesonly=no&graphstatetypes=3";
$url_histogram .= "&timeperiod=".$timeperiod;
$url_histogram .= "&breakdown=".$breakdown;
$url_histogram .= "&t1=".$t1;
$url_histogram .= "&t2=".$t2;
$url_histogram .= "&host=".$hostname;

$ggus_search_url = "https://ggus.eu/ws/ticket_search.php?show_columns_check[]=REQUEST_ID&show_columns_check[]=TICKET_TYPE&show_columns_check[]=AFFECTED_VO&show_columns_check[]=AFFECTED_SITE&show_columns_check[]=PRIORITY&show_columns_check[]=RESPONSIBLE_UNIT&show_columns_check[]=STATUS&show_columns_check[]=DATE_OF_CREATION&show_columns_check[]=LAST_UPDATE&show_columns_check[]=SHORT_DESCRIPTION&ticket=&supportunit=all&vo=biomed&user=&involvedsupporter=&assignto=&affectedsite=&specattrib=0&status=open&priority=all&typeofproblem=all&mouarea=&radiotf=1&timeframe=any&tf_date_day_s=&tf_date_month_s=&tf_date_year_s=&tf_date_day_e=&tf_date_month_e=&tf_date_year_e=&lm_date_day=09&lm_date_month=8&lm_date_year=2011&orderticketsby=GHD_INT_REQUEST_ID&orderhow=descending";

//--- List of services to check
$list_services = array("org.sam.SRM-Put-biomed", "org.sam.SRM-GetSURLs-biomed", "org.sam.SRM-GetTURLs-biomed", "org.sam.SRM-Get-biomed");

?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="fr">
<head>
	<title>	
		Report for SE <?php print $hostname; ?> during the last <?php print $nbDays; ?> days
	</title>
	<link href="styles.css" rel="stylesheet" type="text/css">
	<meta name="robots" content="noindex">

	<script type="text/javascript">
	
	<?php //--- Search open GGUS tickets for that SE
	if ($withGGUSsearch == "on") {
		$ggus_search_url .= "&keyword=".$hostname;
		print "window.open(\"".$ggus_search_url."\",'mywindow');";
	}
	?>
	
	<?php //--- Search info in GOCDB
	if ($withGOCDBsearch == "on") {
		print ("window.open(\"submit-gocdb-search.php?hostname=".$hostname."\");");
	}
	?>

	</script>
	
</head>

<body>
	<!-- Errors management -->
	<?php 
		if (isset($error)) {
			if ($hostname != "") {
				?>
				<div class="error"><?php print $error; ?></div>
				<?php
			} else {
				?>
				<h2>Report error</h2>
				<div class="error"><?php print $error; ?></div>
				</body>
				</html>
				<?php
				exit(0); 
			}
		}
	?>

	<h2>Report for SE <?php print $hostname; ?> during the last <?php print $nbDays; ?> days</h2>

	<?php 
		if ($withTrend=="on" && $withHistogram=="on") 
			$display_style="graphx2";
		else 
			$display_style="graphx1";				
	?>
	<?php foreach ($list_services as $service) { ?>
	
		<div class="section_separator">Service <?php print $service; ?></div>
		
		<?php if ($withTrend=="on" ) { ?>
		<div class="<?php print $display_style; ?>">
			<img src="<?php 
				print $url_trends."&service=".$service;
			?>" name="trends_<?php print $hostname; ?>" border="0">
		</div>
		<?php } ?>
		
		<?php if ($withHistogram=="on" ) { ?>
		<div class="<?php print $display_style; ?>">
			<img src="<?php 
				print $url_histogram."&service=".$service;
			?>" name="alert_<?php print $hostname; ?>" border="0">
		</div>
		<?php } ?>
		
	<?php } ?>

</body>
</html>
