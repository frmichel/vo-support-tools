#!/usr/bin/python

import lfc
from optparse import OptionParser

if __name__ == "__main__":
        parser = OptionParser(usage="%prog <se_name> [--surl] [--dn] [--lfn]", version="%prog 1.3")
	parser.add_option("--surl", action="store_true", dest="surl",    default=False, help="Get Storage URL")
	parser.add_option("--dn",  action="store_true", dest="owner",  default=False, help="Get Owner")
	parser.add_option("--lfn", action="store_true", dest="lfn",    default=False, help="Get LFN")
        (options, args) = parser.parse_args()

	if len(args) >= 3 or len(args) < 1:
		parser.error("wrong number of parameters")

	se_name = args[0]
	users={}

	flags = lfc.CNS_LIST_BEGIN
	lista = lfc.lfc_list()
	replica = lfc.lfc_listreplicax("",se_name, "", flags, lista)

	lfn="\0"*4096

	columns = "fileId"
	columns_sub = "------"
	if options.surl:
		columns += "   |   SURL"
		columns_sub += "-----------"
	if options.lfn:
		columns += "   |   LFN"
		columns_sub += "----------"
	if options.owner:
		columns += "   |   Owner's DN"
		columns_sub += "-----------------"
	print columns
	print columns_sub

	try:
		while replica is not None:
			res = str(replica.fileid)

			if options.surl:
				res += "|" + str(replica.sfn).replace('\0', '')

			if options.lfn:
				lfc.lfc_getpath("", replica.fileid, lfn)
				res = res + "|" + lfn.strip().replace('\0', '')

			if options.owner:
				buf = lfc.lfc_filestatg()
				lfc.lfc_statr(replica.sfn, buf)
					
				username="\0"*1024
				if buf.uid not in users:
					if lfc.lfc_getusrbyuid(buf.uid, username) == 0:
						# Adding user to the list in order to resolve him/her only once
						dn = username.strip().replace('\0', '')
						users[buf.uid] = dn
					else:
						users[buf.uid] = "unknown"
				res = res + "|" + users[buf.uid]
					
			print res

			flags = lfc.CNS_LIST_CONTINUE
			replica = lfc.lfc_listreplicax("",se_name, "", flags, lista)

	except (KeyboardInterrupt, SystemExit):
		print "Interrupted by user."
		
	flags = lfc.CNS_LIST_END
	lfc.lfc_listreplicax("",se_name, "", flags, lista)

	if options.owner:
		print "-----------------------------------------------------"
		print "List of users' DNs:"
		for userId in users:
			print users[userId]
