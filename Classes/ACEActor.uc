// =============================================================================
// AntiCheatEngine - (c) 2009-2016 AnthraX
// =============================================================================
class ACEActor extends IACEActor
      config(System);

// =============================================================================
// Structures
// =============================================================================
// Contains information about the network interfaces in this machine
struct zzNetworkInterface
{
    var string zzNICName;                        // name of the interface - not really relevant
    var string zzIPv4Address;                    // IPv4 Network Address in "x.x.x.x" format (if applicable)
    var string zzIPv4Subnet;                     // IPv4 Subnet Address in "x.x.x.x" format (if applicable)
    var string zzIPv6Address;                    // Network Address in "XXXX:XXXX:..." format (if applicable)
    var string zzIPv6Subnet;                     // Network Address in "XXXX:XXXX:..." format (if applicable)
    var bool   zzListening;                      // Is the ACE PlayerManager listening on this interface?
    var bool   zzWANAccess4;                     // Does this interface have internet access over IPv4?
    var bool   zzWANAccess6;                     // Does this interface have internet access over IPv6?
};

// =============================================================================
// Variables
// =============================================================================
var zzNetworkInterface zzNICS[32];               // Active interfaces
var yyACEWebUpdater    zzIPFetcher;              // Retrieves the WAN ip
var ACENICHelper       zzNICHelper;              // native object used to retrieve NIC information
var ACEMutator         zzMutator;                // Mutator used for admin interaction
var Actor              zzPackageHelper;          // PackageHelper used for screenshot logging/defs file loading/...
var int                zzPlayerManagerProtocol;  // 4 = IPv4, 6 = IPv6
var string             zzPlayerManagerIP;        // IP for the server that will accept the clients - might be local
var string             zzPlayerManagerIPWAN;     //
var int                zzPlayerManagerPort;      // Port for this server
var bool               zzPlayerManagerOK;        // Is the playermanager up and running?
var string             zzPlayerManagerListHash;  // MD5 hash of the serialized filelist used by the playermanager (includes custom files!)
var string             zzPlayerManagerListSigner;// (optional) Signer of the whitelist (includes custom files!)
var bool               zzPlayerManagerError;     // Set when the playermanager connection drops
var bool               zzPlayerManagerCanBindAll;//
var bool               zzLANServer;              //
var bool               zzUpdatingWANIP;          //

// =============================================================================
// MyPostBeginPlay ~
// =============================================================================
function MyPostBeginPlay()
{
	local string zzListenIP;

    // Figure out on which IP's this server is reachable
    xxGetNICInfo();

    // Check Connectivity - This is a hack for servers behind a NAT router.
    if (!xxCheckConnectivity())
        return;

    if (ACEPort != 0)
        zzPlayerManagerPort = ACEPort - 1;
    else
        zzPlayerManagerPort = 0;

    // Spawn and initialize the playermanager uplink
	if (!zzPlayerManagerCanBindAll)
	   zzListenIP = zzPlayerManagerIP;
	else
		zzListenIP = "0.0.0.0";
    if (!xxInitPlayerManagerUplink(zzPlayerManagerProtocol, zzListenIP, zzPlayerManagerPort))
        return;

    // Spawn and register the mutator
    xxInitMutator();

    // Initialize PackageHelper
    if (!xxInitPackageHelper())
        return;

    // Spawn autoconfig if needed
    xxInitAutoConfig();

    // Init Whitelist and push whitelist info to the playermanager
    xxInitWhitelist();

    // All Done! Let the playermanager know that we are ready
	if (zzLink != none)
	{
        zzLink.yCompleteInit(
            Level.Game.GameReplicationInfo.ServerName,
            Left(Level.Game, InStr(Level.Game, ".")),
            GetShortAbsoluteTime());
	}

    SetTimer(0.25, true);

    // Register
    Tag='NPLoader';
}

// =============================================================================
// xxGetNICInfo ~ Retrieves a list of network interfaces and selects the ideal
// interface to listen on (based on connectivity, routing, ...)
// =============================================================================
function xxGetNICInfo()
{
    local int zzI;
	local int zzBest;

	zzBest = -1;
    zzNICHelper  = new(None) class'ACENICHelper';
    zzNICHelper.zzACEActor = self;
    zzNICHelper.yGetNICInfo();
	zzPlayerManagerCanBindAll = true;

	for (zzI = 0; zzI < 32; ++zzI)
	{
		if ((zzNICS[zzI].zzIPv4Address != "" || zzNICS[zzI].zzIPv6Address != "")
		   && !zzNICS[zzI].zzListening)
		   zzPlayerManagerCanBindAll = false;
	}

    for (zzI = 0; zzI < 32; ++zzI)
    {
        if (zzNICS[zzI].zzListening && zzNICS[zzI].zzIPv4Address != "")
        {
		    // compare with the best one we've found so far
			if (zzBest == -1 ||
			   // WAN takes precedence over LAN, which takes precedence over loopback
			   (xxIsLocalIP(zzNICS[zzI].zzIPv4Address) <= xxIsLocalIP(zzNICS[zzBest].zzIPv4Address)) &&
			       (zzNICS[zzI].zzWANAccess4 || !zzNICS[zzBest].zzWANAccess4))
			{
			    zzBest = zzI;
				zzPlayerManagerIP = zzNICS[zzI].zzIPv4Address;
            	zzPlayerManagerProtocol = 4;
			}
        }
    }

    if (zzBest == -1)
    {
		for (zzI = 0; zzI < 32; ++zzI)
        {
            if (zzNICS[zzI].zzListening && zzNICS[zzI].zzIPv6Address != "")
            {
				// compare with the best one we've found so far
				if (zzBest == -1 ||
					// WAN takes precedence over LAN, which takes precedence over loopback
			    	(xxIsLocalIP(zzNICS[zzI].zzIPv6Address, true) <= xxIsLocalIP(zzNICS[zzBest].zzIPv6Address, true)) &&
				   	    (zzNICS[zzI].zzWANAccess6 || !zzNICS[zzBest].zzWANAccess6))
				{
					zzBest = zzI;
					zzPlayerManagerIP = zzNICS[zzI].zzIPv6Address;
            		zzPlayerManagerProtocol = 6;
				}
            }
        }
    }

    if (zzPlayerManagerIP == "")
    {
        if (zzNICHelper.bDebug == 1)
        {
            ACELog("DEBUG: NICHelper did not return any valid WAN IP.");
            ACELog("DEBUG: Trying WAN finder fallback.");
        }
        xxFindWANIP(false);
    }
    else if (zzNICHelper.bDebug == 1)
	{
		if (!zzPlayerManagerCanBindAll)
	        ACELog("DEBUG: NICHelper recommends this ListenIP: " $ zzPlayerManagerIP);
		else
			ACELog("DEBUG: NICHelper recommends listening on all interfaces");
	}
}

// =============================================================================
// xxFindWANIP ~
// =============================================================================
function xxFindWANIP(bool bIsLanServer)
{
    if (ForcedWANIP != "")
        zzPlayerManagerIPWAN = ForcedWANIP;
    else if (bCacheWANIP && CachedWANIP != "")
        zzPlayerManagerIPWAN = CachedWANIP;

    if (!bAutoFindWANIP && ForcedWANIP == "")
    {
        if(bIsLanServer)
        {
            ACELog("WARNING: This is a LAN server and ACE is unable to retrieve the WAN ip.");
            ACELog("WARNING: Unless the correct WAN IP is cached, this server will NOT be");
            ACELog("WARNING: accessible by clients outside the LAN.");
        }
        else
        {
            ACELog("WARNING: This server is directly connected to the internet but ACE");
            ACELog("WARNING: could not figure out the WAN IP. This server will NOT be");
            ACELog("WARNING: accessible to external clients.");
            if (zzNICHelper.bDebug == 1)
            {
                ACELog("DEBUG: Please tell anth that NICHelper is broken for your platform.");
            }
        }
    }

    if (bAutoFindWANIP || ForcedWANIP != "")
    {
        zzUpdatingWANIP = true;
        zzIPFetcher = Level.Spawn(class'yyACEWebUpdater');
        zzIPFetcher.zzActor     = self;
        zzIPFetcher.zzServerNum = -1;
        zzIPFetcher.xxGetWANIP();
    }
}

// =============================================================================
// xxCheckConnectivity ~ Finds the LAN/WAN ip for this server so the server can
// accept clients from both networks
// @return true if successful
// =============================================================================
function bool xxCheckConnectivity()
{
    local int zzTmp;

    zzTmp = xxIsLocalIP(zzPlayerManagerIP);

    if (zzTmp == 2)
    {
		ACELog("ERROR: Your server is not set up properly.");
        ACELog("ERROR: Please use the -MULTIHOME= parameter to specify your ServerIP.");
        ACELog("ERROR: ACE is now disabled.");
        return false;
    }
    else if (zzTmp == 1)
    {
        zzLANServer = true;
        xxFindWANIP(true);
    }
    else
    {
        zzPlayerManagerIPWAN = zzPlayerManagerIP;
    }

    return true;
}

// =============================================================================
// xxInitPlayerManagerUplink
// =============================================================================
function bool xxInitPlayerManagerUplink(int zzProtocol, string zzAddress, int zzPort)
{
	// Redacted
}

// =============================================================================
// xxInitMutator
// =============================================================================
function xxInitMutator()
{
    zzMutator = Level.Spawn(class'ACEMutator');
    zzMutator.zzACEActor = self;
    if (Level.Game.BaseMutator != none)
        Level.Game.BaseMutator.AddMutator(zzMutator);
    else
        Level.Game.BaseMutator = zzMutator;
}

// =============================================================================
// xxInitPackageHelper
// =============================================================================
function bool xxInitPackageHelper()
{
    local class<Actor> zzPHClass;

    zzPHClass = class<Actor>(DynamicLoadObject("PackageHelper_v13.PHActor", class'class', true));
    if (zzPHClass != none)
        zzPackageHelper = Level.Spawn(zzPHClass);

    if (zzPackageHelper == none)
    {
        ACELog("ERROR: ACE Could not load PackageHelper v1.3");
        ACELog("ERROR: The PackageHelper Files are needed for ACE to operate correctly.");
        ACELog("ERROR: Please restore these files and reboot the server.");
        ACELog("ERROR: ACE is now disabled.");
        return false;
    }

    return true;
}

// =============================================================================
// xxInitAutoConfig
// =============================================================================
function xxInitAutoConfig()
{
    local class<Actor> zzACClass;
    local Actor zzAutoConfig;

    if (bAutoConfig)
    {
        zzACClass = class<Actor>(DynamicLoadObject(AutoConfigPackage $ ".ACEAutoConfigActor", class'Class', true));
        if (zzACClass != none)
        {
            zzAutoConfig = Level.Spawn(zzACClass);
            zzAutoConfig.GetItemName("CONFIG");
            zzAutoConfig.Destroy();
        }
        else
        {
            ACELog("ERROR: Could not spawn autoconfig actor:" @ AutoConfigPackage $ ".ACEAutoConfigActor");
        }
    }
}

// =============================================================================
// xxInitWhitelist
// =============================================================================
function xxInitWhitelist()
{
    local string zzTemp, zzTemp2, zzTemp3, zzTemp4;
    local Actor zzAutoConfig;
    local int zzI, zzJ;

    for (zzI = 0; zzI < 255; ++zzI)
    {
        if (UPackages[zzI] == "")
            break;

        zzTemp = zzPackageHelper.GetItemName("GETFILEINFO"@UPackages[zzI]);

        //ACELog(UPackages[zzI]@"fileinfo:"@zzTemp);

        if (xxGetTokenCount(zzTemp, ":::") == 2)
        {
            zzTemp2 = xxGetToken(zzTemp, ":::", 0); // Hash
            zzTemp3 = xxGetToken(zzTemp, ":::", 1); // Size
            zzTemp4 = UPackages[zzI];

            // Figure out file ext
            if (InStr(zzTemp4, ".") != -1)
            {
                zzTemp  = Left(zzTemp4, InStr(zzTemp4, "."));
                zzTemp4 = Mid(zzTemp4, InStr(zzTemp4, ".")+1);
            }
            else
            {
                zzTemp  = UPackages[zzI];
                zzTemp4 = "u";
            }

            ACELog("- UPackage["$zzI$"] - FileName: "$UPackages[zzI]);

			if (zzLink != none)
			    zzLink.yAddPackage(0, zzTemp, zzTemp4, zzTemp2, int(zzTemp3));
        }
        else
        {
            ACELog("- UPackage["$zzI$"] - " $ UPackages[zzI] $ " is not a .u file. Removing");
            UPackages[zzI] = "";
        }
    }

    // Compact UPackages array
    for (zzI = 0; zzI < 255; ++zzI)
    {
        if (UPackages[zzI] == "")
        {
            for (zzJ = zzI; zzJ < 255; ++zzJ)
            {
                if (UPackages[zzJ] != "")
                {
                    UPackages[zzI]       = UPackages[zzJ];
                    UPackages[zzJ]       = "";
                    break;
                }
            }

            if (zzJ >= 255)
                break;
        }
    }

    for (zzI = 0; zzI < 255; ++zzI)
    {
        if (NativePackages[zzI] == "")
            break;

        zzTemp = zzPackageHelper.GetItemName("GETFILEINFO"@NativePackages[zzI]);

        if (xxGetTokenCount(zzTemp, ":::") == 2)
        {
            zzTemp2 = xxGetToken(zzTemp, ":::", 0); // Hash
            zzTemp3 = xxGetToken(zzTemp, ":::", 1); // Size
            zzTemp4 = NativePackages[zzI];

            // Figure out file ext
            if (InStr(zzTemp4, ".") != -1)
            {
                zzTemp  = Left(zzTemp4, InStr(zzTemp4, "."));
                zzTemp4 = Mid(zzTemp4, InStr(zzTemp4, ".")+1);
            }
            else
            {
                zzTemp  = NativePackages[zzI];
                zzTemp4 = "dll";
            }

            ACELog("- NativePackage["$zzI$"] - FileName: "$NativePackages[zzI]);

			if (zzLink != none)
                zzLink.yAddPackage(1, zzTemp, zzTemp4, zzTemp2, int(zzTemp3));
        }
    }
}

// =============================================================================
// GetItemName ~ Event Handler for NPLoader/PlusReplicationInfo
// =============================================================================
function string GetItemName(string zzMessage)
{
    local int zzPID;
    local Pawn zzP;
    local PlayerPawn zzPP;
    local string zzTmp;
    local int zzSOCount;
    local int zzDLLCount;
    local string zzViewPort;
    local string zzCoreHash;

    // NPLoader messages look like "PLAYERJOIN <PID>"
    // This message is only sent if a player joins and has ALL required mods
    // installed. In other words, as soon as this message is received, it is
    // safe to spawn the native object on the client's pc
    if (Left(zzMessage,10) ~= "PLAYERJOIN")
    {
        zzPID      = int(xxGetToken(zzMessage, " ", 1));
        zzDLLCount = int(xxGetToken(zzMessage, " ", 2));
        zzSOCount  = int(xxGetToken(zzMessage, " ", 3));
        zzViewPort = xxGetToken(zzMessage, " ", 4);
        zzCoreHash = xxGetToken(zzMessage, " ", 5);

        // Look for the player in the pawnlist
        for (zzP = Level.PawnList; zzP != None; zzP = zzP.nextPawn)
        {
            if (zzP.IsA('PlayerPawn')
                && zzP.PlayerReplicationInfo != none
                && zzP.PlayerReplicationInfo.PlayerID == zzPID
                && NetConnection(PlayerPawn(zzP).Player) != none)
            {
                zzPP = PlayerPawn(zzP);
                break;
            }
        }

        // Player found
        if (zzPP != none)
        {
            if (zzSOCount > 0 && zzDLLCount <= 0 && InStr(CAPS(zzViewPort), "WIN") == -1)
            {
                ACELog("ACE is not loading for Player: " $ zzP.PlayerReplicationInfo.PlayerName $ " - Reason: Incompatible Operating System (" $ zzViewport $ ")");
                return "";
            }

            xxInitNewPlayer(zzPP);
        }
    }

    return "";
}

// =============================================================================
// xxNotifySetServer ~ Called when the playermanager is ready to accept clients
// =============================================================================
function xxNotifySetServer(string zzIP, int zzPort, string zzWhitelistHash, string zzWhitelistSigner)
{
    local ACEReplicationInfo zzRI;

    zzPlayerManagerIP              = zzIP;
    zzPlayerManagerPort            = zzPort;
    zzPlayerManagerOK              = true;
    zzPlayerManagerListHash        = zzWhitelistHash;
    zzPlayerManagerListSigner      = zzWhitelistSigner;

    ACELog("PlayerManager Initialization Complete.");
    if (zzLANServer)
    {
        ACELog("- This is a LAN server.");
        ACELog("- LAN ListenIP: " $ zzPlayerManagerIP $ ":" $ zzPlayerManagerPort);
    }

    if (zzPlayerManagerIPWAN == "" && !zzUpdatingWANIP)
        ACELog("- WAN ListenIP: This server is NOT accessible from outside the LAN.");
    else if (zzUpdatingWANIP)
        ACELog("- WAN ListenIP: " $ zzPlayerManagerIPWAN $ ":" $ zzPlayerManagerPort $ " [UPDATING]");
    else if (zzPlayerManagerIPWAN != "")
        ACELog("- WAN ListenIP: " $ zzPlayerManagerIPWAN $ ":" $ zzPlayerManagerPort);

    if (zzPlayerManagerListSigner != "" && Left(zzPlayerManagerListSigner, 8) != "unsigned")
        ACELog("- The server's filelist was signed by: " $ zzPlayerManagerListSigner);
    else if (zzPlayerManagerListSigner != "" && Left(zzPlayerManagerListSigner, 8) == "unsigned")
        ACELog("- This server's filelist is unsigned! Reason: " $ Mid(zzPlayerManagerListSigner, 10));
    else
        ACELog("- This server's filelist is unsigned!");

    // Init pass 2 for all existing ri objects
    for (zzRI = ACEReplicationInfo(CheckList); zzRI != none; zzRI = ACEReplicationInfo(zzRI.NextCheck))
        xxInitHandshake(zzRI);
}

// =============================================================================
// xxShutdown ~ Something went really really wrong...
// =============================================================================
function xxShutDown()
{
    if (zzLink != none)
    {
        zzLink.Destroy();
        zzLink = none;
    }
    zzPlayerManagerOK = false;
}

// =============================================================================
// xxAddNIC
// =============================================================================
function xxAddNIC(string zzNICName, string zzIPv4Addr, string zzIPv4Subnet,
    string zzIPv6Addr, string zzIPv6Subnet, bool zzListen, bool zzWAN4, bool zzWAN6)
{
    local int zzI;

    for (zzI = 0; zzI < 32; ++zzI)
        if (zzNICS[zzI].zzNICName == "")
            break;

    if (zzI >= 32)
        return;

    //Log("AddNIC: " $ zzNICName $ " - " $ zzIPv4Addr $ " - " $ zzWAN4 $ " " $ zzListen);
    zzNICS[zzI].zzNICName       = zzNICName;
    zzNICS[zzI].zzIPv4Address   = zzIPv4Addr;
    zzNICS[zzI].zzIPv4Subnet    = zzIPv4Subnet;
    zzNICS[zzI].zzIPv6Address   = zzIPv6Addr;
    zzNICS[zzI].zzIPv6Subnet    = zzIPv6Subnet;
    zzNICS[zzI].zzListening     = zzListen;
    zzNICS[zzI].zzWANAccess4    = zzWAN4;
    zzNICS[zzI].zzWANAccess6    = zzWAN6;
}

// =============================================================================
// xxIsLocalIP
// returns:
// 0 = wan ip
// 1 = local ip
// 2 = loopback ip
// =============================================================================
function int xxIsLocalIP(string zzIP, optional bool zzIPv6)
{
    if (!zzIPv6)
    {
        if (Left(zzIP, 4) == "127." || Left(zzIP, 2) == "0")
            return 2;
        if (Left(zzIP, 3) == "10." || Left(zzIP, 7) == "172.16." || Left(zzIP, 8) == "192.168.")
            return 1;
        return 0;
    }
    else
    {
        // TODO
        return 0;
    }
}

// =============================================================================
// GetShortAbsoluteTime ~ Copied from StatLog
// =============================================================================
function string GetShortAbsoluteTime()
{
    local string AbsoluteTime;

    AbsoluteTime = string(Level.Year);

    if (Level.Month < 10)
        AbsoluteTime = AbsoluteTime$".0"$Level.Month;
    else
        AbsoluteTime = AbsoluteTime$"."$Level.Month;

    if (Level.Day < 10)
        AbsoluteTime = AbsoluteTime$".0"$Level.Day;
    else
        AbsoluteTime = AbsoluteTime$"."$Level.Day;

    if (Level.Hour < 10)
        AbsoluteTime = AbsoluteTime$".0"$Level.Hour;
    else
        AbsoluteTime = AbsoluteTime$"."$Level.Hour;

    if (Level.Minute < 10)
        AbsoluteTime = AbsoluteTime$".0"$Level.Minute;
    else
        AbsoluteTime = AbsoluteTime$"."$Level.Minute;

    if (Level.Second < 10)
        AbsoluteTime = AbsoluteTime$".0"$Level.Second;
    else
        AbsoluteTime = AbsoluteTime$"."$Level.Second;

    return AbsoluteTime;
}

// =============================================================================
// Tick ~
// =============================================================================
function Tick(float DeltaTime)
{
    if (zzPlayerManagerError)
    {
        Disable('Tick');
        xxShutdown();
    }
}

// =============================================================================
// xxPlayerManagerDisconnected
// =============================================================================
function xxPlayerManagerDisconnected()
{
	zzPlayerManagerError = true;
}

// =============================================================================
// Destroyed ~ Fix suggested by Higor
// =============================================================================
event Destroyed()
{
    if(zzNICHelper != none)
    {
        zzNICHelper.zzACEActor = none;
        zzNICHelper = none;
    }

    Super.Destroyed();
}

// =============================================================================
// defaultproperties
// =============================================================================
defaultproperties
{
    bAlwaysTick=true
    ACEVersion="@ACESHORTVERLOWER@"
}
