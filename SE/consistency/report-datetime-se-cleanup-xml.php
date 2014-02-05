<?php
        header ("Content-Type:text/xml; charset=utf-8");

        // Check parameters
        if (array_key_exists("datetime", $_GET)) {
                if ($_GET['datetime'] == ""){
                        print "<error>Please provide a date and time in parameter \"datetime\"</error>";
        		exit(0);}
	}
        else{
                print "<error>Please provide a date and time in parameter \"datetime\"</error>";
                exit(0);
        }
	
	
        $datetime = $_GET['datetime'];

        if (array_key_exists("vo", $_GET)) {
                if ($_GET['vo'] == ""){
                        print "<error>Please provide a vo name in parameter \"vo\"</error>";
                        exit(0);}
        }
        else{
                print "<error>Please provide a vo in parameter \"vo\"</error>";
                exit(0);
        }


        $vo = $_GET['vo'];

        print "<checks>\n";
	print "<datetime>";
	ereg("([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})", $datetime, $arDate);
	print $arDate[1]."-".$arDate[2]."-".$arDate[3]." ".$arDate[4].":".$arDate[5].":".$arDate[6];
	print "</datetime>\n";
	if (file_exists("../../$vo/cleanup-se/$datetime/list_ses_urls.xml")){
		print file_get_contents("../../$vo/cleanup-se/$datetime/list_ses_urls.xml");	
	} 
               
	print "<results>\n";
  	$localdir = opendir("../../$vo/cleanup-se/$datetime");
       
  	while ($file = readdir($localdir))
        {
                if (!is_dir($file) && ereg("^(.*)_check_result.xml$", $file, $arName)){
                        print file_get_contents("../../$vo/cleanup-se/$datetime/$file");
		}
        }
	print "</results>\n";
	print "</checks>";
?>

