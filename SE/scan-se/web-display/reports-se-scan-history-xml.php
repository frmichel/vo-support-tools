<?php
	// Check parameters
        if (array_key_exists("vo", $_GET)) {
                if ($_GET['vo'] == ""){
                        print "<error>Please provide a vo name in parameter \"vo\"</error>";
                        exit(0);}
        }
        else{
                print "<error>Please provide a vo name in parameter \"vo\"</error>";
                exit(0);
        }
        $vo = $_GET['vo'];
	
	print "<scans>";
	$localdir = opendir("../../$vo/scan-se");
        $listDirs = array();
        while ($dir = readdir($localdir))
        {
                if (is_dir("../../$vo/scan-se/$dir") && ereg("([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})", $dir, $arDate))
                        $listDirs[$dir] = $arDate;
        }

        arsort($listDirs);
        foreach ($listDirs as $dir => $arDate)
        {
		
                // Build the date & time string from the directory name
                $formattedDate = $arDate[1]."-".$arDate[2]."-".$arDate[3]." ".$arDate[4].":".$arDate[5].":".$arDate[6];
		print "<scan date=\"".$formattedDate."\">";
                // Get the additional info
                if (file_exists("../../$vo/scan-se/$dir/INFO.xml")) {
                        print file_get_contents("../../$vo/scan-se/$dir/INFO.xml");
                }
		print "</scan>";

        } // end foreach 
	
        closedir($localdir);
	print "</scans>";
?>
