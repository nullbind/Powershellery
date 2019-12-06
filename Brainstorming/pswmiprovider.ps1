This is a stand alone script to create a basic WMI provider

                # -----------------------------------
                # Setup and Compile WMI Provider DLL
                # -----------------------------------

                # Status user
                write-output " * Generating WMI provider C# Code"

                # Create random WMI name space
                $WMINameSpaceLen = (5..10 | Get-Random -count 1 )
                $WMINameSpace = (-join ((65..90) + (97..122) | Get-Random -Count $WMINameSpaceLen | % {[char]$_}))
                write-output " *  - WMI Provider name space: $WMINameSpace"

                # Create random WMI class name                                        
                $WMIClassLen = (5..10 | Get-Random -count 1 )
                $WMIClass = (-join ((65..90) + (97..122) | Get-Random -Count $WMIClassLen | % {[char]$_}))
                write-output " *  - WMI Provider class: $WMIClass"

                # Create random WMI method name
                $WMIMethodLen = (5..10 | Get-Random -count 1 )        
                $WMIMethod = (-join ((65..90) + (97..122) | Get-Random -Count $WMIMethodLen | % {[char]$_}))
                write-output " *  - WMI Provider Method: $WMIMethod "

                # Create random WMI provider file name
                $WmiFileNameLen = (5..10 | Get-Random -count 1 )                                        
                $WmiFileName = (-join ((65..90) + (97..122) | Get-Random -Count $WmiFileNameLen | % {[char]$_}))
                write-output " *  - WMI Provider file name: $WmiFileName.dll"

                # Define WMI provider code
                $WMICS = "
                using System;
                using System.Collections;
                using System.Management;
                using System.Management.Instrumentation;
                using System.Runtime.InteropServices;
                using System.Configuration.Install;

                [assembly: WmiConfiguration(@`"root\cimv2`", HostingModel = ManagementHostingModel.LocalSystem)]
                namespace $WMINameSpace
                {
                    [System.ComponentModel.RunInstaller(true)]
                    public class MyInstall : DefaultManagementInstaller
                   {
                        //private static string fileName = System.Diagnostics.Process.GetCurrentProcess().MainModule.FileName;

                        public override void Install(IDictionary stateSaver)
                        {
                            try
                            {
                                new System.EnterpriseServices.Internal.Publish().GacInstall(`"$WmiFileName.dll`");
                                base.Install(stateSaver);
                                RegistrationServices registrationServices = new RegistrationServices();
                            }
                            catch { }
                        }

                        public override void Uninstall(IDictionary savedState)
                        {

                            try
                            {
                                new System.EnterpriseServices.Internal.Publish().GacRemove(`"$WmiFileName.dll`");
                                ManagementClass managementClass = new ManagementClass(@`"root\cimv2:Win32_$WMIClass`");
                                managementClass.Delete();
                            }
                            catch { }

                            try
                            {
                                base.Uninstall(savedState);
                            }
                            catch { }
                        }
                    }

                    [ManagementEntity(Name = `"Win32_$WMIClass`")]
                    public class $WMIClass
                    {
                        [ManagementTask]
                        public static string $WMIMethod(string command, string parameters)
                        {

                            // Write a file to c:\temp\doit.txt using wmi
                            object[] theProcessToRun = { `"c:\\windows\\system32\\cmd.exe /C \`"echo testing123$WMIMethod > c:\\temp\\doit.txt \`"`" };
                            ManagementClass mClass = new ManagementClass(@`"\\`" + `"127.0.0.1`" + @`"\root\cimv2:Win32_Process`");
                            mClass.InvokeMethod(`"Create`", theProcessToRun);

                            // Return test script
                            return `"test`";
                        }
                    }
                }"

                $WMICS

                # Write c sharp code to a file
                $OutDir = $env:temp
                $OutFileName = $WmiFileName 
                $OutFilePath = "$OutDir\$OutFileName.cs"
                write-output " * Writing WMI provider code to: $OutFilePath"
                $WMICS | Out-File $OutFilePath

                # Identify the path to csc.exe
                write-output " * Searching for .net framework v4 csc.exe" 
                $CSCPath = Get-ChildItem -Recurse "C:\Windows\Microsoft.NET\" -Filter "csc.exe" | where {$_.FullName -like "*v4*" -and $_.fullname -like "*Framework64*"} | Select-Object fullname -First 1 -ExpandProperty fullname
                if(-not $CSCPath){
                    write-output " * No csc.exe found."
                    return
                }else{
                    write-output " * Found csc.exe: $CSCPath"
                }

                # Compile the .cs file to a .dll using csc.exe
                $CurrentDirectory = pwd
                cd $OutDir
                $Command = "$CSCPath /target:library /R:system.configuration.install.dll /R:system.enterpriseservices.dll /R:system.management.dll /R:system.management.instrumentation.dll " + $OutFilePath        
                write-output " * Compiling WMI provider code to: $OutDir\$OutFileName.dll"
                $Results = Invoke-Expression $Command
                cd $CurrentDirectory
                $WMIFilePath1 = "$OutDir\$OutFileName.dll"
                write-output " * Removing $OutDir\$OutFileName.cs"
                del "$OutDir\$OutFileName.cs"
                
                write-output " * Moving $OutFileName.dll to: c:\windows\system32\wbem\$OutFileName.dll"
                move "$OutDir\$OutFileName.dll" "c:\windows\system32\wbem\$OutFileName.dll"

                # Identify the path to installutil.exe
                write-output " * Searching for .net framework v4 InstallUtil.exe" 
                $InstallUtilPath = Get-ChildItem -Recurse "C:\Windows\Microsoft.NET\" -Filter "installutil.exe" | where {$_.FullName -like "*v4*" -and $_.fullname -like "*Framework64*"} | Select-Object fullname -First 1 -ExpandProperty fullname
                if(-not $InstallUtilPath){
                    write-output " * No InstallUtil.exe found."
                    return
                }else{
                    write-output " * Found InstallUtil.exe: $InstallUtilPath"
                }

                # Register the wmi provider
                $Commandwmi = "$InstallUtilPath c:\windows\system32\wbem\$OutFileName.dll"        
                write-output " * Registering WMI provider from c:\windows\system32\wbem\$OutFileName.dll with class Win32_$WMIClass"
                $Resultswmi = Invoke-Expression $Commandwmi

                # Confirm installation
                $Classcheck = Get-CimClass | where cimclassname -like "Win32_$WMIClass" | Select CimClassName -ExpandProperty CimClassName
                if($Classcheck){
                    write-output " * Confirmed Win32_$WMIClass was registered correctly."
                }else{
                    write-output " * The Win32_$WMIClass does not exist.  Something went wrong."
                    return
                }
                   
                Write-Output " * Manual wmic command: invoke-wmimethod -class Win32_$WMIClass -Name $WMIMethod"


                # Confirm the provider was installed
                function Get-Providers ($ns="root") {
                   Get-WmiObject -Namespace $ns -Class "__NAMESPACE" |
                   foreach {
                       Get-WmiObject -NameSpace $currNameSpace -Class __Win32Provider | select @{n="Namespace";e=    {$("$ns\" + $_.Name)}},@{n="Provider";e={$_.Name}}
                       Get-Providers $("$ns\" + $_.Name) 
                   } 
                }

                # get addtional information about the provider
                # Get-Providers | where provider -like "*$WmiFileName*"
                # Get-Providers | where namespace -like "*$WmiFileName*"
                # provider = assembly name
                # Get-WmiObject -Class __InstanceProviderRegistration | where provider -like "*$WmiFileName*"
               
                # Remove WMI provider
                Write-Output " * Removing provider $WmiFileName"
                # note that this does remove the class and method...
                # Get-WmiObject -Class __InstanceProviderRegistration | where provider -like "*$WmiFileName*" | Remove-WmiObject
                
