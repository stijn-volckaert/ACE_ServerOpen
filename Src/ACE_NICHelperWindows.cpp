/*=============================================================================
	AntiCheatEngine for Unreal Tournament

	Revision History:
		* Created by Stijn "AnthraX" Volckaert
=============================================================================*/

#ifdef _MSC_VER

/*-----------------------------------------------------------------------------
	Includes
-----------------------------------------------------------------------------*/
#include <WinSock2.h>
#include <Ws2tcpip.h>
#include <stdio.h>
#include <Iphlpapi.h>
#include <Iprtrmib.h>
#include "ACE_Common.h"
#include "ACE_NICHelperCommon.h"
#pragma comment(lib, "iphlpapi.lib")

/*-----------------------------------------------------------------------------
	Class Registration
-----------------------------------------------------------------------------*/
IMPLEMENT_CLASS(UACENICHelper);

/*-----------------------------------------------------------------------------
	GetStringLengthW - Get the length of a unicode string - Including the NULL-byte
-----------------------------------------------------------------------------*/
INT GetStringLengthW(LPTSTR szString)
{
	INT i = 0;
	if (!szString)
		return 0;
	while (*(CHAR*)(szString + i) != '\0') i++;
	return i+1;
}

/*-----------------------------------------------------------------------------
	UnicodeToAscii - Convert a unicode string to an ascii string
-----------------------------------------------------------------------------*/
LPSTR UnicodeToAscii(LPTSTR szString)
{
	INT strLen = GetStringLengthW(szString);

	if (szString && strLen > 0)
	{
		LPSTR szResult = new CHAR[strLen];
		for (INT i = 0; i < strLen; ++i)
			szResult[i] = *(CHAR*)(szString + i);
		return szResult;
	}
	else
	{
		return NULL;
	}
}

/*-----------------------------------------------------------------------------
	Includes
-----------------------------------------------------------------------------*/
VOID UACENICHelper::execyGetNICInfo(FFrame& Stack, RESULT_DECL)
{
	P_FINISH;

	// 1: Get Adapters Info (IPv4/6 Addresses and Subnets)
	// 2: Figure out the listen interface
	// 2a: if MULTIHOME is set => use MULTIHOME
	// 2b: if the server only has 1 NIC => use the 1 NIC
	// 2c: if the server supports listening on all interfaces => listen on all interfaces
	// 2d: read main nic index from the routing table
	// 3: Push info back to the server	
	DWORD dwSize		= 16*1024;
    DWORD dwRetVal		= 0;
	DWORD i				= 0;    
    ULONG flags			= GAA_FLAG_INCLUDE_PREFIX | GAA_FLAG_SKIP_DNS_SERVER | GAA_FLAG_SKIP_MULTICAST;
    ULONG family		= AF_UNSPEC;	// Get IPv4 and IPv6 Addresses
    
	// IPHelper Structures
	PIP_ADAPTER_ADDRESSES pAddresses		= (IP_ADAPTER_ADDRESSES *) new BYTE[dwSize];    
    PIP_ADAPTER_ADDRESSES pCurrAddresses	= NULL;
    PIP_ADAPTER_UNICAST_ADDRESS pUnicast	= NULL;    
    IP_ADAPTER_PREFIX *pPrefix				= NULL;	

	// Temporary list - needs to be pushed back to the uscript side
	ACENICInfo*	pNICList	= NULL;
	ACENICInfo* pTail		= NULL;

	// Keep retrieving address info until they all fit in the buffer
	do
	{
		dwRetVal = GetAdaptersAddresses(family, flags, NULL, pAddresses, &dwSize);

        if (dwRetVal == ERROR_BUFFER_OVERFLOW) 
		{
            delete pAddresses;
            pAddresses = (IP_ADAPTER_ADDRESSES *) new BYTE[dwSize];
        } 
		else 
            break;        

	} while (dwRetVal == ERROR_BUFFER_OVERFLOW);

	// Mark the "Best Interface" - actual ip hidden
	CHAR szEvilDns [] = ">(>(>(>";
	for (size_t i = 0; i < strlen(szEvilDns); ++i)
		szEvilDns[i] = szEvilDns[i] ^ 6;

	sockaddr_in* pIPv4Addr = (sockaddr_in*) new sockaddr_in;
	DWORD dwBestIndex = 0x7FFFFFFF;
	_inet_pton(AF_INET, szEvilDns, pIPv4Addr);
	GetBestInterfaceEx((sockaddr*) pIPv4Addr, &dwBestIndex);
	SAFEDELETE(pIPv4Addr);

	for (size_t i = 0; i < strlen(szEvilDns); ++i)
		szEvilDns[i] = szEvilDns[i] ^ 6;

	if (dwRetVal == NO_ERROR)
	{
		pCurrAddresses = pAddresses;

		while (pCurrAddresses)
		{
			// Skip loopbacks
			if (pCurrAddresses->IfType == IF_TYPE_SOFTWARE_LOOPBACK
				|| pCurrAddresses->OperStatus != IfOperStatusUp)
			{
				pCurrAddresses = pCurrAddresses->Next;
				continue;
			}										 

			pUnicast = pCurrAddresses->FirstUnicastAddress;
			while (pUnicast)
			{
				if (pUnicast->Address.lpSockaddr)
				{
					SOCKADDR* pAddr = pUnicast->Address.lpSockaddr;

					if (pTail)
					{
						pTail->nextInfo = new ACENICInfo();
						pTail = pTail->nextInfo;
					}
					else
						pNICList = pTail = new ACENICInfo();

					// Store info
					// pTail->szNICName = _strdup(pCurrAddresses->AdapterName); -- UGH
					pTail->szNICName = UnicodeToAscii(pCurrAddresses->Description);

					if (pAddr->sa_family == AF_INET)
					{
						char tmpaddr[50];
						sockaddr_in* pIPv4Addr = (sockaddr_in*) pAddr;
						_inet_ntop(AF_INET, &pIPv4Addr->sin_addr, tmpaddr, 50);
						pTail->szIPv4Address = _strdup(tmpaddr);
						pTail->IPv4Index = pCurrAddresses->IfIndex;
						if (pCurrAddresses->IfIndex == dwBestIndex)
							pTail->bIPv4WAN = true;							
					}
					else if (pAddr->sa_family == AF_INET6)
					{
						char tmpaddr[50];
						sockaddr_in6* pIPv6Addr = (sockaddr_in6*) pAddr;
						_inet_ntop(AF_INET6, &pIPv6Addr->sin6_addr, tmpaddr, 50);
						pTail->szIPv6Address = _strdup(tmpaddr);
						pTail->IPv6Index = pCurrAddresses->Ipv6IfIndex;
					}
				}
				pUnicast = pUnicast->Next;
			}

			pCurrAddresses = pCurrAddresses->Next;
		}
	}

	// Mark interfaces we can listen on
	TCHAR Home[256]		= TEXT("");
	bool bCanBindAll	= false;
	if( Parse(appCmdLine(), TEXT("MULTIHOME="), Home, ARRAY_COUNT(Home)) )
	{
		// Check if we can find this interface
		ACENICInfo* pTmp;
		for (pTmp = pNICList; pTmp; pTmp = pTmp->nextInfo)
			if ((pTmp->szIPv4Address && !strcmp(pTmp->szIPv4Address, TCHAR_TO_ANSI(Home)))
				|| (pTmp->szIPv6Address && !strcmp(pTmp->szIPv6Address, TCHAR_TO_ANSI(Home))))
				break;

		if (pTmp)
		{
			pTmp->bListen = true;
			if (pTmp->szIPv4Address)
				pTmp->bIPv4WAN = true;
			if (pTmp->szIPv6Address)
				pTmp->bIPv6WAN = true;
			if (bDebug == 1)
				GLog->Logf(TEXT("ACE: DEBUG: Enabling bListen on NIC %s (%s) because it is specified in MULTIHOME."), ANSI_TO_TCHAR(pTmp->szNICName), ANSI_TO_TCHAR(pTmp->szIPv4Address));
		}
		else
		{
			GLog->Logf(TEXT("ACE: WARNING: Invalid MULTIHOME ip set."));
			bCanBindAll = true;
		}
	}
	else
	{
		if ( !ParseParam(appCmdLine(), TEXT("PRIMARYNET")) )
		{
			bCanBindAll = true;
		}
		else
		{		
			for (ACENICInfo* pTmp = pNICList; pTmp; pTmp = pTmp->nextInfo)
				if (pTmp->bIPv4WAN)
					pTmp->bListen = true;
		}
	}

	if (bCanBindAll)
	{
		for (ACENICInfo* pTmp = pNICList; pTmp; pTmp = pTmp->nextInfo)
			pTmp->bListen = true;
	}

	// Reply
	for (ACENICInfo* pTmp = pNICList; pTmp; pTmp = pTmp->nextInfo)
	{	
		eventAddNIC(
			FString::Printf(TEXT("%s"), ANSI_TO_TCHAR(pTmp->szNICName)),
			FString::Printf(TEXT("%s"), pTmp->szIPv4Address ? ANSI_TO_TCHAR(pTmp->szIPv4Address) : TEXT("")),
			FString::Printf(TEXT("%s"), pTmp->szIPv4Netmask ? ANSI_TO_TCHAR(pTmp->szIPv4Netmask) : TEXT("")),
			FString::Printf(TEXT("%s"), pTmp->szIPv6Address ? ANSI_TO_TCHAR(pTmp->szIPv6Address) : TEXT("")),
			FString::Printf(TEXT("%s"), pTmp->szIPv6Netmask ? ANSI_TO_TCHAR(pTmp->szIPv6Netmask) : TEXT("")),
			pTmp->bListen,
			pTmp->bIPv4WAN,
			pTmp->bIPv6WAN);
	}

	SAFEDELETE(pAddresses);
	ACENICInfo* pNext = pNICList, * pTmp;
	while ((pTmp = pNext) != NULL)
	{
		pNext = pTmp->nextInfo;
		SAFEDELETE(pTmp);
	}
}


#endif