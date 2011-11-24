<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">

<head>
  <title>Full SE reports history for biomed VO</title>
  <link href="styles.css" rel="stylesheet" type="text/css">
  <meta name="robots" content="noindex">
</head>

<body id="body_form">
<h2>Full SE reports history for biomed VO</h2>

	<div class="form_bloc">
<?php
	$localdir = opendir(".");
	while ($dir = readdir($localdir))
	{
		if (is_dir($dir) && ereg("([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})", $dir, $date)) {
			$formatedDate = $date[1]."-".$date[2]."-".$date[3]."&nbsp;".$date[4]."h".$date[5]."m".$date[6]."s";
?>		<div class="font_medium line_height_2">
<?php
			print "<a href=\"report-full-se.php?datetime=$dir\">$formatedDate</a>";
			print "</div>";
			
		}

	}
	closedir($localdir);
?>

</div>
</body>
</html>
