<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">

<head>
  <title>Full SE reports history for biomed VO</title>
  <link href="styles.css" rel="stylesheet" type="text/css">
  <meta name="robots" content="noindex">
</head>

<body id="body_form">
<h2>SE space reports history for biomed VO</h2>

<div class="form_bloc">

	<table id="reports_history_tab">
		<tr id="tab_header">
			<th>Month</th>
			<th>Scan date</th>
			<th>SE min filling rate</th>
			<th>User's min space</th>
		</tr>

<?php
	$localdir = opendir(".");
	$listDirs = array();
	while ($dir = readdir($localdir))
	{
		if (is_dir($dir) && ereg("([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})", $dir, $arDate))
			$listDirs[$dir] = $arDate;
	}
	
	arsort($listDirs);
	$lastMonth="0000-00";
	foreach ($listDirs as $dir => $arDate)
	{
       	$currentMonth=$arDate[1]."-".$arDate[2];
		if ($currentMonth != $lastMonth)
				print "		<tr><td>$currentMonth</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>\n";
		$lastMonth = $currentMonth;

		// Build the date & time string from the directory name
		$formatedDate = $arDate[1]."-".$arDate[2]."-".$arDate[3]."&nbsp;".$arDate[4]."h".$arDate[5]."m".$arDate[6]."s";
		
		// Get the additional info
		$minRate = "n.a";
		$userMinSpace = "n.a";
		if (file_exists($dir."/INFO.htm")) {
			$fh = fopen($dir."/INFO.htm", "r");
			fgets($fh);		// ignore first line
			fscanf($fh, "SE minimum used space: %s<br>", $minRate);
			fscanf($fh, "Users minimum used space: %s", $userMinSpace);
			fclose($fh);
		}
?>		<tr>
			<td>&nbsp;</td>
			<td><?php
				print "<a href=\"report-full-se.php?datetime=$dir\">$formatedDate</a>";
			?></td>
			<td><?php print $minRate; ?></td>
			<td><?php print $userMinSpace; ?></td>
		</tr>
<?php
	} // end foreach 
	closedir($localdir);
?>

	</table>

</div>
</body>
</html>

