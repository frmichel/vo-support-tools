<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">

<head>
  <title>Report of full Storage Elements for VO biomed</title>
  <link href="styles.css" rel="stylesheet" type="text/css">
  <meta name="robots" content="noindex">
</head>

<body id="body_form">
<h2>Report of full SEs for VO biomed</h2>

<?php 
	// Check parameters
	if (array_key_exists("datetime", $_GET)) {
		if ($_GET['datetime'] == "")
			$error = "Please provide a date and time in parameter \"datetime\"";
	}
	else
		$error = "Please provide a date and time in parameter \"datetime\"";

	// Errors management
	if (isset($error)) {
		?>
		<div class="error">ERROR: <?php print $error; ?></div>
		</body>
		</html>
		<?php
		exit(0); 
	}
	
	$datetime = $_GET['datetime'];
?>

	<!-- Report header -->
	<div class="line_height_2 font_bold">
	<?php include $datetime."/INFO.htm"; ?>
	</div>
	<div class="right font_small">
	<a href="reports-history.php">Reports history</a>
	</div>

<?php
	$localdir = opendir($datetime);
	while ($file = readdir($localdir))
	{
		if (!is_dir($file) && ereg("^(.*)_users$", $file, $arName)) {
			$seHostName = $arName[1];
			?>
			<div class="form_bloc">
				<div class="form_bloc_title font_bold left"><?php print "$seHostName"; ?></div>
				
				<div class="form_bloc_title font_small left">Users</div>
				<div class="left font_medium">
					<a href="<?php print "$datetime/$seHostName"; ?>_email">Email template</a>
					<pre><?php include "$datetime/$file"; ?></pre>
				</div>

				<?php if (file_exists("$datetime/$seHostName"."_unknown")) { ?>
				<div class="form_bloc_title font_small left">Unknwon users (no longer in the VO)</div>
				<div class="left font_medium">
					<pre><?php include "$datetime/$seHostName"."_unknown"; ?></pre>
				</div>
				<?php } ?>
				
			</div>
			<?php
		}
	}
	closedir($localdir);
?>


</body>
</html>
