# This Powershell function wraps around the native Windows netsessenum function
# http://msdn.microsoft.com/en-us/library/windows/desktop/bb525382%28v=vs.85%29.aspx
# It is able to recover information about active sessions locally and across the network
function Get-NetSessions {

    param(
    [string]$ComputerName = "192.168.1.109",
    [string]$ComputerSession = "",
    [string]$UserName = "",
    [int]$QueryLevel

    )

$DebugPreference = 'continue'

$signature = @'
[DllImport("netapi32.dll", SetLastError=true)]
public static extern int NetSessionEnum(
        [In,MarshalAs(UnmanagedType.LPWStr)] string ServerName,
        [In,MarshalAs(UnmanagedType.LPWStr)] string UncClientName,
        [In,MarshalAs(UnmanagedType.LPWStr)] string UserName,
        Int32 Level,
        out IntPtr bufptr,
        int prefmaxlen,
        ref Int32 entriesread,
        ref Int32 totalentries,
        ref Int32 resume_handle);
'@




$SessionInfoStructures = @'
namespace pinvoke {
using System;
using System.Runtime.InteropServices;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct SESSION_INFO_0
    {
    [MarshalAs(UnmanagedType.LPWStr)]
    public String sesi0_cname;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct SESSION_INFO_1
    {
    [MarshalAs(UnmanagedType.LPWStr)]
    public string sesi1_cname;
    [MarshalAs(UnmanagedType.LPWStr)]
    public string sesi1_username;
    public uint sesi1_num_opens;
    public uint sesi1_time;
    public uint sesi1_idle_time;
    public uint sesi1_user_flag;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct SESSION_INFO_2
    {
    [MarshalAs(UnmanagedType.LPWStr)]
    public string sesi2_cname;
    [MarshalAs(UnmanagedType.LPWStr)]
    public string sesi2_username;
    public uint  sesi2_num_opens;
    public uint  sesi2_time;
    public uint  sesi2_idle_time;
    public uint  sesi2_user_flags;
    [MarshalAs(UnmanagedType.LPWStr)]
    public string sesi2_cltype_name;
    }


    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct SESSION_INFO_10
    {
    [MarshalAs(UnmanagedType.LPWStr)]
    public string sesi10_cname;
    [MarshalAs(UnmanagedType.LPWStr)]
    public string sesi10_username;
    public uint sesi10_time;
    public uint sesi10_idle_time;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct SESSION_INFO_502
    {
    [MarshalAs(UnmanagedType.LPWStr)]
    public string sesi502_cname;
    [MarshalAs(UnmanagedType.LPWStr)]
    public string sesi502_username;
    public uint sesi502_num_opens;
    public uint sesi502_time;
    public uint sesi502_idle_time;
    public uint sesi502_user_flags;
    [MarshalAs(UnmanagedType.LPWStr)]
    public string sesi502_cltype_name;
    [MarshalAs(UnmanagedType.LPWStr)]
    public string sesi502_transport;
    }

    public enum NERR
    {
    /// <summary>
    /// Operation was a success.
    /// </summary>
    NERR_Success = 0,
    /// <summary>
    /// More data available to read. dderror getting all data.
    /// </summary>
    ERROR_MORE_DATA = 234,
    /// <summary>
    /// Network browsers not available.
    /// </summary>
    ERROR_NO_BROWSER_SERVERS_FOUND = 6118,
    /// <summary>
    /// LEVEL specified is not valid for this call.
    /// </summary>
    ERROR_INVALID_LEVEL = 124,
    /// <summary>
    /// Security context does not have permission to make this call.
    /// </summary>
    ERROR_ACCESS_DENIED = 5,
    /// <summary>
    /// Parameter was incorrect.
    /// </summary>
    ERROR_INVALID_PARAMETER = 87,
    /// <summary>
    /// Out of memory.
    /// </summary>
    ERROR_NOT_ENOUGH_MEMORY = 8,
    /// <summary>
    /// Unable to contact resource. Connection timed out.
    /// </summary>
    ERROR_NETWORK_BUSY = 54,
    /// <summary>
    /// Network Path not found.
    /// </summary>
    ERROR_BAD_NETPATH = 53,
    /// <summary>
    /// No available network connection to make call.
    /// </summary>
    ERROR_NO_NETWORK = 1222,
    /// <summary>
    /// Pointer is not valid.
    /// </summary>
    ERROR_INVALID_HANDLE_STATE = 1609,
    /// <summary>
    /// Extended Error.
    /// </summary>
    ERROR_EXTENDED_ERROR= 1208,
    /// <summary>
    /// Base.
    /// </summary>
    NERR_BASE = 2100,
    /// <summary>
    /// Unknown Directory.
    /// </summary>
    NERR_UnknownDevDir = (NERR_BASE + 16),
    /// <summary>
    /// Duplicate Share already exists on server.
    /// </summary>
    NERR_DuplicateShare = (NERR_BASE + 18),
    /// <summary>
    /// Memory allocation was to small.
    /// </summary>
    NERR_BufTooSmall = (NERR_BASE + 23)
    }

    public enum SESSION_LEVEL
    {
    /// <summary>
    /// ZERO
    /// </summary>
    LEVEL_0 = 0,
    /// <summary>
    /// ONE
    /// </summary>
    LEVEL_1 = 1,
    /// <summary>
    /// TWO
    /// </summary>
    LEVEL_2 = 2,
    /// <summary>
    /// TEN
    /// </summary>
    LEVEL_10 = 10,
    /// <summary>
    /// FIVE HUNDRED AND TWO
    /// </summary>
    LEVEL_502 = 502
    }
}
'@



# Add the custom structures and enums
Add-Type $SessionInfoStructures


# Add the function definition
Add-Type -MemberDefinition $signature -Name Win32Util -Namespace Pinvoke -Using Pinvoke


if ([Pinvoke.SESSION_LEVEL]::LEVEL_0 -eq $QueryLevel) {$x = New-Object pinvoke.SESSION_INFO_0}
if ([Pinvoke.SESSION_LEVEL]::LEVEL_1 -eq $QueryLevel) {$x = New-Object pinvoke.SESSION_INFO_1}
if ([Pinvoke.SESSION_LEVEL]::LEVEL_2 -eq $QueryLevel) {$x = New-Object pinvoke.SESSION_INFO_2}
if ([Pinvoke.SESSION_LEVEL]::LEVEL_10 -eq $QueryLevel) {$x = New-Object pinvoke.SESSION_INFO_10}
if ([Pinvoke.SESSION_LEVEL]::LEVEL_502 -eq $QueryLevel) {$x = New-Object pinvoke.SESSION_INFO_502}

# Declare the reference variables
$type = $x.gettype()
Write-Debug "$type.tostring()"

$ptrInfo = 0 
$EntriesRed = 0
$TotalRead = 0
$ResumeHandle = 0

# Call the function
$Result = [pinvoke.Win32Util]::NetSessionEnum($ComputerName,$ComputerSession,$UserName,$QueryLevel,[ref]$ptrInfo,-1,[ref]$EntriesRed,[ref]$TotalRead,[ref]$ResumeHandle)

$Result


if ($Result -eq ([pinvoke.NERR]::NERR_Success)){

    Write-Debug 'Result is success'
    Write-Debug "IntPtr $ptrInfo"
    Write-Debug "Entries read $EntriesRed"
    Write-Debug "Total Read $TotalRead"


    # Locate the offset of the initial intPtr
    $offset = $ptrInfo.ToInt64()
    Write-Debug "Starting Offset $offset"

    # Work out how mutch to increment the pointer by finding out the size of the structure
    $Increment = [System.Runtime.Interopservices.Marshal]::SizeOf($x)
    Write-Debug "Increment $Increment"


    for ($i = 0; ($i -lt $EntriesRed); $i++){

        $newintptr = New-Object system.Intptr -ArgumentList $offset
        Write-Debug "Newintptr `[$i`] $newintptr"
        $Info = [system.runtime.interopservices.marshal]::PtrToStructure($newintptr,$type)
        $Info | Select-Object *
        $offset = $newintptr.ToInt64()
        $offset += $increment
    }

} else {
        # Error code lookups
        # http://msdn.microsoft.com/en-us/library/windows/desktop/ms681381(v=vs.85).aspx
        # http://msdn.microsoft.com/en-us/library/windows/desktop/aa370674(v=vs.85).aspx
        switch ($Result)
        {
                   (5)       {Write-Host "The user does not have access to the requested information."} 
                   (124)       {Write-Host "The value specified for the level parameter is not valid."} 
                   (87)   {Write-Host 'The specified parameter is not valid.'} 
                   (234)           {Write-Host 'More entries are available. Specify a large enough buffer to receive all entries.'} 
                   (8)   {Write-Host 'Insufficient memory is available.'} #8 
                   (2312)   {Write-Host 'A session does not exist with the computer name.'} 
                   (2351)      {Write-Host 'The computer name is not valid.'} 
                   (2221)   {Write-Host 'The user name could not be found.'}           
        }
}
}


# notes: 
# Session Tests
# map share (temp or persistent) to dc = always shows = 100% initially, but some of the sessions seem to time out after x idle.... 
# map share from domain system lva to hva = ?
# rdp to dc = only during the authentication process ( a few seconds) then it is gone
# rdp to domain system lva to hva = ?

# Tracking sessions via DCs
# RDP to DC
# Persistent share to DC
# RDP to Memebers server
# Persistent share to Memebers server
# RDP to work station
# Persistent share to work station

Get-NetSessions -QueryLevel 0
