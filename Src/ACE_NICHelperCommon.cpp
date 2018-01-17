/*=============================================================================
	AntiCheatEngine for Unreal Tournament

	Revision History:
		* Created by Stijn "AnthraX" Volckaert
=============================================================================*/

/*-----------------------------------------------------------------------------
	Includes
-----------------------------------------------------------------------------*/
#include "ACE_Common.h"
#include "ACE_NICHelperCommon.h"
#include <string.h>

/*-----------------------------------------------------------------------------
	Constructor
-----------------------------------------------------------------------------*/
ACENICInfo::ACENICInfo()	
{
	memset(this, 0, sizeof(*this));
}

/*-----------------------------------------------------------------------------
	Destructor
-----------------------------------------------------------------------------*/
ACENICInfo::~ACENICInfo()
{
	SAFEDELETE(szNICName);
	SAFEDELETE(szIPv4Address);
	SAFEDELETE(szIPv4Netmask);
	SAFEDELETE(szIPv6Address);
	SAFEDELETE(szIPv6Netmask);
}

/*-----------------------------------------------------------------------------
	FindNIC ~ Searches the Linked List for the NIC with the specified name
-----------------------------------------------------------------------------*/
ACENICInfo* ACENICInfo::FindNIC(char* szName)
{
	for (ACENICInfo* tmp = this; tmp; tmp = tmp->nextInfo)
		if (!strcmp(szName, tmp->szNICName))
			return tmp;
	return NULL;
}
