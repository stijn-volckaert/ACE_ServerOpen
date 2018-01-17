// =============================================================================
// AntiCheatEngine - (c) 2009-2016 AnthraX
// =============================================================================
class ACENICHelper extends Object
    native
    noexport
    config(System);

// =============================================================================
// Variables
// =============================================================================
var ACEActor zzACEActor;
var config int bDebug;

// =============================================================================
// Native Functions
// =============================================================================
native function yGetNICInfo();

// =============================================================================
// Callback Events
// =============================================================================
event yAddNIC(string zzNICName, string zzIPv4Addr, string zzIPv4Subnet,
    string zzIPv6Addr, string zzIPv6Subnet, bool zzListen, bool zzWAN4, bool zzWAN6)
{
    if (zzACEActor != none)
    {
        if (bDebug == 1)
        {
            zzACEActor.ACELog("DEBUG: ACE found the following network card: " $ zzNICName);
            if (zzIPv4Addr != "")
                zzACEActor.ACELog("DEBUG: - IPv4 Properties -> Address: " $ zzIPv4Addr $ " - Subnet: " $ zzIPv4Subnet $ " - Internet Access: " $ zzWAN4);
            if (zzIPv6Addr != "")
                zzACEActor.ACELog("DEBUG: - IPv6 Properties -> Address: " $ zzIPv6Addr $ " - Subnet: " $ zzIPv6Subnet $ " - Internet Access: " $ zzWAN6);
            zzACEActor.ACELog("DEBUG: - Can listen on this interface? " $ zzListen);
        }

        zzACEActor.xxAddNIC(zzNICName, zzIPv4Addr, zzIPv4Subnet, zzIPv6Addr,
            zzIPv6Subnet, zzListen, zzWAN4, zzWAN6);
    }
}