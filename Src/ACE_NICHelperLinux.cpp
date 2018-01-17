/*=============================================================================
	AntiCheatEngine for Unreal Tournament

	Revision History:
		* Created by Stijn "AnthraX" Volckaert
=============================================================================*/

/*-----------------------------------------------------------------------------
	Includes
-----------------------------------------------------------------------------*/
#include "ACE_Common.h"
#include "ACE_Private.h"
#include "ACE_NICHelperCommon.h"
#include <stdio.h>
#include <sys/types.h>
#include <ifaddrs.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>

/*-----------------------------------------------------------------------------
	Class Registration
-----------------------------------------------------------------------------*/
IMPLEMENT_CLASS(UACENICHelper);

/*-----------------------------------------------------------------------------
	popen_and_read - perform shell command and return output
-----------------------------------------------------------------------------*/
char* popen_and_read(const char* command)
{
	FILE* fp = popen(command, "r");
	char buf[1024];

	if (!fp)
		return NULL;

	memset(buf, 0, 1024);
	fread(buf, 1, 1023, fp);
	pclose(fp);

	if (strlen(buf) > 1)
	{
		// Cut off trailing CR/LF
		for (int i = 0; i < 2; ++i)
			if (buf[strlen(buf)-1] == 10 || buf[strlen(buf)-1] == 13)
				buf[strlen(buf)-1] = 0;
	}

	return _strdup(buf);
}

/*-----------------------------------------------------------------------------
	Includes
-----------------------------------------------------------------------------*/
void UACENICHelper::execyGetNICInfo(FFrame& Stack, RESULT_DECL)
{
	P_FINISH;

	// 1: Get Adapters Info (IPv4/6 Addresses and Subnets)
	// 2: Figure out the listen interface
	// 2a: if MULTIHOME is set => use MULTIHOME
	// 2b: if the server only has 1 NIC => use the 1 NIC
	// 2c: if the server supports listening on all interfaces => listen on all interfaces
	// 2d: read main nic index from the routing table
	// 3: Push info back to the server

	// Get default ipv4 and ipv6 gateways
	char*		wan_ipv4	= popen_and_read("/sbin/route -A inet 2>&1 | grep default | sed 's/.* //'");
	if (!wan_ipv4) // works on most linux distros
				wan_ipv4	= popen_and_read("/bin/netstat -r 2>&1 | grep default | sed 's/.* //'");
	if (!wan_ipv4) // works on FreeBSD
				wan_ipv4	= popen_and_read("/usr/bin/netstat -r 2>&1 | grep default | sed 's/.* //'");
	char*		wan_ipv6	= popen_and_read("/sbin/route -A inet6 2>&1 | grep default | sed 's/.* //'");

	if (wan_ipv4)
	{
		if (bDebug != 1)
			ACEDBG(TEXT("Default IPv4 WAN NIC = %s"), ANSI_TO_TCHAR(wan_ipv4));
		else
			GLog->Logf(TEXT("ACE: DEBUG: Default IPv4 WAN NIC = %s"), ANSI_TO_TCHAR(wan_ipv4));
	}
	if (wan_ipv6)
	{
		if (bDebug != 1)
			ACEDBG(TEXT("Default IPv6 WAN NIC = %s"), ANSI_TO_TCHAR(wan_ipv6));
		else
			GLog->Logf(TEXT("ACE: DEBUG: Default IPv6 WAN NIC = %s"), ANSI_TO_TCHAR(wan_ipv6));
	}

	// Temporary list - needs to be pushed back to the uscript side
	ACENICInfo*	pNICList	= NULL;
	ACENICInfo* pTail		= NULL;
	ACENICInfo*	pTmp		= NULL;

	// use getifaddrs to retrieve all ip addresses. This function is not
	// POSIX compliant but it is present on all BSD, OS X and Linux systems
	struct ifaddrs *ifaddr, *ifa;
	if (getifaddrs(&ifaddr) == -1)
	{
		GLog->Logf(TEXT("ACE: ERROR: Could not retrieve the local ip addresses - error: %d (%s)"), 
				   errno, ANSI_TO_TCHAR(strerror(errno)));
		SAFEDELETE(wan_ipv4);
		SAFEDELETE(wan_ipv6);
		return;
	}

	for (ifa = ifaddr; ifa; ifa = ifa->ifa_next)
	{
		// Skip interfaces without valid IPv4/6 addresses
		if (!ifa->ifa_addr
			|| (ifa->ifa_addr->sa_family != AF_INET && ifa->ifa_addr->sa_family != AF_INET6))
			continue;

		// Alloc info struct
		if (pTail)
		{
			pTail->nextInfo = new ACENICInfo();
			pTail = pTail->nextInfo;
		}
		else
			pNICList = pTail = new ACENICInfo();

		// Store info
		pTail->szNICName = _strdup(ifa->ifa_name);

		struct sockaddr_in* pAddr = (struct sockaddr_in*)ifa->ifa_addr;
		if (ifa->ifa_addr->sa_family == AF_INET)
		{
			char tmpaddr[50];
			inet_ntop(AF_INET, &pAddr->sin_addr, tmpaddr, 50);
			pTail->szIPv4Address	= _strdup(tmpaddr);

			char* colon = strrchr(pTail->szIPv4Address, ':');
			if (colon) colon[0] = '\0';
		}
		else
		{
			char tmpaddr[50];
			inet_ntop(AF_INET6, &pAddr->sin_addr, tmpaddr, 50);
			pTail->szIPv6Address	= _strdup(tmpaddr);
		}
	}

	// Mark interfaces with WAN access
	for (pTmp = pNICList; pTmp; pTmp = pTmp->nextInfo)
	{
		if (!_stricmp(pTmp->szNICName, wan_ipv4))
			pTmp->bIPv4WAN = TRUE;
		if (!_stricmp(pTmp->szNICName, wan_ipv6))
			pTmp->bIPv6WAN = TRUE;
	}

	// Mark interfaces we can listen on
	TCHAR Home[256]		= TEXT("");
	UBOOL bCanBindAll	= FALSE;
	if( Parse(appCmdLine(), TEXT("MULTIHOME="), Home, ARRAY_COUNT(Home)) )
	{
		// Check if we can find this interface
		for (pTmp = pNICList; pTmp; pTmp = pTmp->nextInfo)
			if ((pTmp->szIPv4Address && !strcmp(pTmp->szIPv4Address, TCHAR_TO_ANSI(Home)))
				|| (pTmp->szIPv6Address && !strcmp(pTmp->szIPv6Address, TCHAR_TO_ANSI(Home))))
				break;

		if (pTmp)
		{
			pTmp->bListen  = TRUE;
			pTmp->bIPv4WAN = TRUE;
			if (bDebug == 1)
				GLog->Logf(TEXT("ACE: DEBUG: Enabling bListen on NIC %s (%s) because it is specified in MULTIHOME."), ANSI_TO_TCHAR(pTmp->szNICName), ANSI_TO_TCHAR(pTmp->szIPv4Address));
		}
		else
		{
			GLog->Logf(TEXT("ACE: WARNING: Invalid MULTIHOME ip set."));
			bCanBindAll = TRUE;
		}
	}
	else
	{
		if ( !ParseParam(appCmdLine(), TEXT("PRIMARYNET")) )
		{
			bCanBindAll = TRUE;
		}
		else
		{
			for (pTmp = pNICList; pTmp; pTmp = pTmp->nextInfo)
				if (pTmp->bIPv4WAN)
					pTmp->bListen = TRUE;
		}
	}

	if (bCanBindAll)
	{
		for (pTmp = pNICList; pTmp; pTmp = pTmp->nextInfo)
			pTmp->bListen = TRUE;
	}

	// Reply
	for (pTmp = pNICList; pTmp; pTmp = pTmp->nextInfo)
	{
		eventAddNIC(
			FString::Printf(TEXT("%s"), ANSI_TO_TCHAR(pTmp->szNICName)),
			FString::Printf(TEXT("%s"), pTmp->szIPv4Address ? ANSI_TO_TCHAR(pTmp->szIPv4Address) : TEXT("")),
			TEXT(""),
			FString::Printf(TEXT("%s"), pTmp->szIPv6Address ? ANSI_TO_TCHAR(pTmp->szIPv6Address) : TEXT("")),
			TEXT(""),
			pTmp->bListen,
			pTmp->bIPv4WAN,
			pTmp->bIPv6WAN);
	}

	ACENICInfo* pNext = pNICList;
	while ((pTmp = pNext) != NULL)
	{
		pNext = pTmp->nextInfo;
		SAFEDELETE(pTmp);
	}
	SAFEDELETE(wan_ipv4);
	SAFEDELETE(wan_ipv6);
	freeifaddrs(ifaddr);
}
