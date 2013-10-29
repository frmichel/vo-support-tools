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

?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">

<head>

	<link href="styles.css" rel="stylesheet" type="text/css">

	<script type="text/javascript">
		// Form validation: at least a name and comment must be entered
		function validateForm()
		{
			frm = document.forms['formCheckSE'];
			if (frm['idHostname'].value == "")
			{
				alert("Please fill in the SE hostname");
				return false;
			}
			else
				return true;
		}
	</script>

	<title>
		Report generator for biomed Storage Elements
	</title>
	<meta name="robots" content="noindex">
</head>

<body id="body_form">
	<h2>Report generator for biomed Storage Elements</h2>
	<div class="right font_small_bold centp"><?php print VERSION; ?></div>
	
	<!-- Form to generate histograms on one SEs + GGUS search -->
	<div class="form_bloc">

		<div class="form_bloc_title font_bold left">Report probes for an individual SE</div>
		
		<form id="formCheckSE" action="check-single-se.php" method="get" enctype="multipart/form-data" onsubmit="return validateForm()">
			<table>
				<tr>
					<td>SE hostname</td>
					<td><input id="idHostname" name="hostname" value="<?php print(getCookie('hostname')); ?>"></td>
				</tr>
				<tr>
					<td>Time range</td>
					<td>
						<select name="nbDays">
							<option selected value="7">Last 7 days</option> 
							<option value="30">Last 30 days</option> 
							<option value="60">Last 60 days</option> 
							<option value="90">Last 90 days</option> 
							<option value="180">Last 180 days</option> 
						</select> 
					</td>
				</tr>
				<tr>
					<td>Generate trend report</td>
					<td><input type="checkbox" name="withTrend" <?php if (getCookie('withTrendSingle')=="on") print "checked"; ?>></td>
				</tr>
				<tr>
					<td>Generate alert histogram report</td>
					<td><input type="checkbox" name="withHistogram" <?php if (getCookie('withHistogramSingle')=="on") print "checked"; ?>></td>
				</tr>
				<tr>
					<td>Open GGUS tickets related to SE</td>
					<td><input type="checkbox" name="withGGUSsearch" <?php if (getCookie('withGGUSsearchSingle')=="on") print "checked"; ?>></td>
				</tr>
				<tr>
					<td>Open GOCDB search</td>
					<td><input type="checkbox" name="withGOCDBsearch" <?php if (getCookie('withGOCDBsearchSingle')=="on") print "checked"; ?>></td>
				</tr>
				<tr>
					<td>&nbsp;</td>
					<td><input value="Submit" type="submit"></td>
				</tr>
			</table>
		</form>
	</div>
		
		
	<!-- Form to generate reports on all SEs for one probe -->
	<div class="form_bloc">

		<div class="form_bloc_title font_bold left">Report one probe for all SEs</div>

		<form id="formCheckSE" action="check-all-se.php" method="get" enctype="multipart/form-data">
		
			<table>
				<tr>
					<td>Service probe</td>
					<td>
						<select name="service">
							<option value="put">org.sam.SRM-Put-biomed</option> 
							<option value="getsurl">org.sam.SRM-GetSURLs-biomed</option>
							<option value="getturl">org.sam.SRM-GetTURLs-biomed</option> 
							<option value="get">org.sam.SRM-Get-biomed</option> 
						</select> 
					</td>
				</tr>
				<tr>
					<td>Time range</td>
					<td>
						<select name="nbDays">
							<option selected value="7">Last 7 days</option> 
							<option value="30">Last 30 days</option> 
							<option value="60">Last 60 days</option> 
							<option value="90">Last 90 days</option> 
							<option value="180">Last 180 days</option> 
						</select> 
					</td>
				</tr>
				<tr>
					<td>Generate trend report</td>
					<td><input type="checkbox" name="withTrend" <?php if (getCookie('withTrendAll')=="on") print "checked"; ?>></td>
				</tr>
				<tr>
					<td>Generate alert histogram report</td>
					<td><input type="checkbox" name="withHistogram" <?php if (getCookie('withHistogramAll')=="on") print "checked"; ?>></td>
				</tr>
				<tr>
					<td>&nbsp;</td>
					<td><input value="Submit" type="submit"></td>
				</tr>
			</table>
		</form>
	</div>

	<!-- Form to generate reports on all SEs for 3 probes -->
	<div class="form_bloc">

		<div class="form_bloc_title font_bold left">Report 3 probes for all SEs</div>

		<form id="formCheckSE" action="check-all-se-3probes.php" method="get" enctype="multipart/form-data">
		
			<table>
				<tr>
					<td>Time range</td>
					<td>
						<select name="nbDays">
							<option selected value="7">Last 7 days</option> 
							<option value="30">Last 30 days</option> 
							<option value="60">Last 60 days</option> 
							<option value="90">Last 90 days</option> 
							<option value="180">Last 180 days</option> 
						</select> 
					</td>
				</tr>
				<tr>
					<td>Generate trend report</td>
					<td><input type="checkbox" name="withTrend" <?php if (getCookie('withTrendAll3Probes')=="on") print "checked"; ?>></td>
				</tr>
				<tr>
					<td>Generate alert histogram report</td>
					<td><input type="checkbox" name="withHistogram" <?php if (getCookie('withHistogramAll3Probes')=="on") print "checked"; ?>></td>
				</tr>
				<tr>
					<td>&nbsp;</td>
					<td><input value="Submit" type="submit"></td>
				</tr>
			</table>
		</form>
	</div>
	
</body>
</html>
