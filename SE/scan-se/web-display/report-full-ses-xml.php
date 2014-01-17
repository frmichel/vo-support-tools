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

        print "<scans>\n";
	print "<datetime>";
	ereg("([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})", $datetime, $arDate);
	print $arDate[1]."-".$arDate[2]."-".$arDate[3]." ".$arDate[4].":".$arDate[5].":".$arDate[6];
	print "</datetime>\n";
	print "<info>";
	if (file_exists("../../$vo/scan-se/$datetime/INFO.xml")) {
	print file_get_contents("../../$vo/scan-se/$datetime/INFO.xml");
	}
	print "</info>\n";	

	$localdir = opendir("../../$vo/scan-se/$datetime");
        $arUsersFiles = array();
        $arStatusFiles = array();
  while ($file = readdir($localdir))
        {
                if (!is_dir($file) && ereg("^(.*)_users.xml$", $file, $arName))
                        $arUsersFiles[] = $file;
                if (!is_dir($file) && ereg("^(.*)_status.xml$", $file, $arName))
                        $arStatusFiles[] = $file;
        }

        sort($arStatusFiles);
	print "<scan-status>\n";
        foreach ($arStatusFiles as $id => $file) {
                print "<scan-status-se>"; 
		print file_get_contents("../../$vo/scan-se/$datetime/$file");	
        	print "</scan-status-se>\n";
	} 
               
        print "</scan-status>\n";

        // Generate the blocs for each SE
        sort($arUsersFiles);
        foreach ($arUsersFiles as $id => $file)
        {
                print "<scan-se>\n";
		ereg("^(.*)_users.xml$", $file, $arName);
                $seHostName = $arName[1];
                print "<HostName>".$seHostName."</HostName>\n";
		print "<Users>\n";
		print file_get_contents("../../$vo/scan-se/$datetime/$file");
		print "</Users>\n";
		if (file_exists("../../$vo/scan-se/$datetime/$seHostName"."_suspended-expired.xml")) {		
		print "<SuspendedExpired>\n";
		print file_get_contents("../../$vo/scan-se/$datetime/$seHostName"."_suspended-expired.xml");
		print "</SuspendedExpired>\n";
		}
 		if (file_exists("../../$vo/scan-se/$datetime/$seHostName"."_unknown.xml")) {
		print "<Unknown>\n";
		print file_get_contents("../../$vo/scan-se/$datetime/$seHostName"."_unknown.xml");
		print "</Unknown>\n";
		}
		print file_get_contents("../../$vo/scan-se/$datetime/$seHostName"."_email.xml");
		print "\n</scan-se>\n";        	
	}
        closedir($localdir);
	print "</scans>";
?>

