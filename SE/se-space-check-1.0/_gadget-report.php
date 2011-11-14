<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
    <body>
         <div id="loader" style="width:100px;background-color:red;color:white">Loading...</div>
    </body>
        <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <title></title>
        <link rel='stylesheet' type='text/css' href='http://appdb.egi.eu/gadgets/resources/skins/default/default.css' id='skincss' />
        <script type="text/javascript" src="http://ajax.microsoft.com/ajax/jquery/jquery-1.5.min.js"></script>
        <script type="text/javascript" src="http://appdb.egi.eu/gadgets/resources/scripts/gadgets.js" ></script>
        <script type='text/javascript'>gadgets.config = {"op_response":"html","op":"appdb.applications.list","oppars":{"discipline":"3","pagelength":"5","pageoffset":"0"},"vname":"simplelist","vpart":null,"skin":null,"vpars":{"title":"SE Space Checker","search":"true"},"base":"\/gadgets\/gadget-report.php"};
</script>

<script type="text/javascript">
    $(document).ready(function(){
        $("#loader").hide();
        $(".view-container").show();
    });
    </script>
    </head>
    <body>
        <div id="ajaxloader" style="display:none" >
            <img alt="" style="position:absolute;display:inline-block;top:0;left:0;z-index:1000;width:100%;height:100%;opacity:0.4;filter:alpha(opacity=40);-moz-opacity: .4;" src="http://appdb.egi.eu/gadgets/resources/images/white.png" />
            <img alt="" style="position:absolute;display:inline-block;width:40px;height:40px;top:45%;left:45%;dispaly:none;" src="http://appdb.egi.eu/gadgets/resources/images/ajax-loader.gif" />
        </div>
        <div class="view-container" style="display:none;">
        <div  id='v_appdb_applications_list' class='viewpart'>
				
	<table cellpadding="0" cellspacing="0">
    <tr>
        <td>
            <div class="docktop header">
            <div id='p_appdb_applications_header' class='viewpart'> 
			<table style="table-layout: fixed;width:100%;" cellSpacing="0" cellPadding="0" border="0" align="center" width="100%">
		        <tr align="left" style="width:100%;">
		            <td style="width:60px;padding-right:30px;">
		                <a href="http://www.egi.eu" target="_blank" style="text-decoration: none;border-style:none;display:block;color:white;overflow:hidden;">
		                <img src="http://appdb.egi.eu/images/EGI-logo_small2.png" width="40px" height="20px" alt="www.egi.eu" style="text-decoration: none;border-style: none;color:white;" />
		                </a>
		            </td>
		            <td align="center" style="width:75%;" >
		                <div style="width:100%;">
		                    <center style="width:100%">Applications Database</center>
		                </div>                  
		            </td>
					
		            <td align="right" style="min-width:75px;float:right;">
		                <a id="searchlink" onclick="gadgets.appdb.applications.toggleSearch();" style="font-size: x-small;text-decoration: none;cursor:pointer;vertical-align: middle;padding-right:5px;">
		                    <img src="http://appdb.egi.eu/gadgets/resources/skins/default/images/search.png" alt="Search" title="Search applications database" width="20px" height="20px" />
		                </a>
		                <a id="clearquerylink" onclick="gadgets.appdb.applications.revertToBaseQuery();" style="font-size: x-small;text-decoration: none;cursor:pointer;vertical-align: middle;padding-right:5px;display:none;">
		                    <img src="http://appdb.egi.eu/gadgets/resources/skins/default/images/undo.png" alt="Clear" title="Clear search and refresh items" width="20px" height="20px" />
		                </a>
		                <a id="helplink" onclick="gadgets.appdb.applications.showHelp(this);" style="font-size: x-small;text-decoration: none;cursor:pointer;vertical-align: middle;padding-right:5px;" href="#">
		                    <img title="Click for help" alt="Help"  width="20px" height="20px" border="0" src="http://appdb.egi.eu/gadgets/resources/skins/default/images/help.png"/>
		                </a>
		            </td>
		        </tr>
			</table>
        </td>
    </tr>
	
    <tr>
        <td>
            <div class="listContainer">
				<div >
					<table style="table-layout: fixed" cellSpacing="0" cellPadding="10">
						<tr >
							<th>Hostname</th><th>Available (GB)</th><th>Used (GB)</th><th>Total (GB)</th><th>%age used</th>
						</tr >
						<tr >
							<td>tbn18.nikhef.nl</td>
							<td style="text-align: right">0</td>
							<td style="text-align: right">2198</td>
							<td style="text-align: right">2198</td>
							<td style="text-align: right">99</td>
						</tr >
						<tr >
							<td>tbn18.nikhef.nl</td>
							<td style="text-align: right">0</td>
							<td style="text-align: right">2198</td>
							<td style="text-align: right">2198</td>
							<td style="text-align: right">99</td>
						</tr >
						<tr >
							<td>tbn18.nikhef.nl</td>
							<td style="text-align: right">0</td>
							<td style="text-align: right">2198</td>
							<td style="text-align: right">2198</td>
							<td style="text-align: right">99</td>
						</tr >
					</table>					
				</div>
			</div>
        </td>
    </tr>
	
    <tr>
        <td>
            <div class="dockbottom" >
	            <table class="footer" cellSpacing="0" cellPadding="0" width="100%">
	                <tbody>
	                    <tr>
	                        <td valign="bottom" >
	                            <div class="signature" style="text-align: center;color:#676767;">
	                                   <a target="_blank" href="http://www.iasa.gr/" class="hiddentext" style="text-decoration: none;font-size: smaller;color:#676767;">
	                                       <font>&copy; Institute of Accelerating Systems and Applications, 2009-2011, Athens, Greece</font>
	                                   </a>
	                            </div>
	                        </td>
	                    </tr>
	                    <tr>
	                        <td valign="top">
	                        </td>
	                    </tr>
	                </tbody>
	            </table>
            </div>
        </td>
    </tr>
</table>

</div>        
</div>
</body>
</html>
