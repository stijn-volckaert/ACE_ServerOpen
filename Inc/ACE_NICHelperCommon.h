/*=============================================================================
	AntiCheatEngine for Unreal Tournament

	Revision History:
		* Created by Stijn "AnthraX" Volckaert
=============================================================================*/

/*-----------------------------------------------------------------------------
	Includes
-----------------------------------------------------------------------------*/
#include "ACE_Private.h"

/*-----------------------------------------------------------------------------
	ACENICInfo Class
-----------------------------------------------------------------------------*/
class ACENICInfo
{
public:
	// Constructor/Destructor
	ACENICInfo();
	~ACENICInfo();
	ACENICInfo*	FindNIC(char* szName);

	// Variables
	char*		szNICName;		// Name of the NIC - Used as the Identifier
	char*		szIPv4Address;	// IPv4 Network Address
	char*		szIPv4Netmask;	// IPv4 Network Mask
	int			IPv4Index;		// IPv4 Interface Index
	char*		szIPv6Address;	// IPv6 Network Address
	char*		szIPv6Netmask;	// IPv6 Network Mask
	int			IPv6Index;		// IPv4 Interface Index
	bool		bListen;		// Can we listen on this NIC?	
	bool		bIPv4WAN;		// Does this interface have IPv4 Interwebz access?
	bool		bIPv6WAN;		// Does this interface have IPv6 Interwebz access?
	ACENICInfo*	nextInfo;		// Linked List
};