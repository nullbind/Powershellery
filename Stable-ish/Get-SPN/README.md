Powershellery - Get-SPN
=======================

Displays Service Principal Names (SPN) for domain accounts based on SPN service name, 
domain account, or domain group via LDAP queries. This information can be used to 
identify systems running specific services and the domain accounts running them.  
For example, this script could be used to locate domain systems where SQL Server has been 
installed.  It can also be used to help find systems where members of the Domain Admins 
group might be logged in if the accounts where used to run services on the domain 
(which is very common).  So this should be handy for both system administrators and 
penetration testers.  The script currently supports trusted connections and provided
credentials.

	Find servers running specific services.
	Examples: 
	
	Get-SPN  -type service -search "*www*"
	Get-SPN  -type service -search "MSSQLSvc*"
	Get-SPN  -type service -search "MSSQLSvc*" -List yes 
	Get-SPN  -type service -search "*vnc*" -list yes | select server -Unique
	Get-SPN  -type service -search "MSSQLSvc*" -List yes | Select Server 
	Get-SPN  -type service -search "MSSQLSvc*" -DomainController 192.168.1.100 -Credential domain\user
	Get-SPN  -type service -search "MSSQLSvc*" -List yes -DomainController 192.168.1.100 -Credential domain\user 
	Get-SPN  -type service -search "MSSQLSvc*" -List yes -DomainController 192.168.1.100 -Credential domain\user | Select Server  

	Find servers where a specific user is registered to run services.
	Examples:
	Get-SPN  -type user -search "serveradmin"
	Get-SPN  -type user -search "sqladmin"
	Get-SPN  -type user -search "sqladmin" -List yes | format-table -autosize
	Get-SPN  -type user -search "sqladmin" -List yes | Select Server | format-table -autosize
	Get-SPN  -type user -search "sqladmin" -DomainController 192.168.1.100 -Credential domain\user
	Get-SPN  -type user -search "sqladmin" -List yes -DomainController 192.168.1.100 -Credential domain\user 
	Get-SPN  -type user -search "sqladmin" -List yes -DomainController 192.168.1.100 -Credential domain\user | Select Server

	Find servers where members of a specific group are registered to run services.	 
	Get-SPN  -type group -search "Domain Users"
	Get-SPN  -type group -search "Domain Admins"
	Get-SPN  -type group -search "Domain Admins" -List yes | format-table -autosize
	Get-SPN  -type group -search "Domain Admins" -List yes | Select Server | format-table -autosize
	Get-SPN  -type group -search "Domain Admins" -DomainController 192.168.1.100 -Credential domain\user
	Get-SPN  -type group -search "Domain Admins" -List yes -DomainController 192.168.1.100 -Credential domain\user 
	Get-SPN  -type group -search "Domain Admins" -List yes -DomainController 192.168.1.100 -Credential domain\user | Select Server 
	
	Links:
	http://www.netspi.com
	http://msdn.microsoft.com/en-us/library/windows/desktop/ms677949(v=vs.85).aspx
	http://technet.microsoft.com/en-us/library/cc731241.aspx
	http://technet.microsoft.com/en-us/library/cc978021.aspx
	
	Notes:
	Author: Scott Sutherland 2013, NetSPI
	Version: Get-SPN v.1
	Requirements: Powershell v.3
	Comments: The technique used to query LDAP was based on the "Get-AuditDSDisabledUserAcount" 
	function found in Carols Perez's PoshSec-Mod project.	
