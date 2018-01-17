// =============================================================================
// AntiCheatEngine - (c) 2009-2011 AnthraX
// =============================================================================
class yyACEWebUpdater extends TcpLink;

// =============================================================================
// Global Variables
// =============================================================================
var ACEActor zzActor;
var int      zzServerNum;  // Server we're trying to get wan ip from
var int      zzState;      // 0 = getting latest, 1 = getting ACE.defs, 2 = getting WAN ip
var float    zzStart;      //
var bool     zzTicking;    // if true data is being read
var int      zzSize;       // total size of the file
var int      zzBytes;      // bytes downloaded so far
var string   zzCF;         // carriage return (chr(13)) + line feed (chr(10))
var bool     zzHeaderRead; // HTTP Header read?
var bool     zzResponded;  // Got response?
var string   zzLine;       // Got data?
var string   zzLatest;     //
var string   zzServerURI;  // utgl.unrealadmin.org
var string   zzServerPath; // /ACE/latest.txt

// =============================================================================
// xxGetIP ~
// =============================================================================
function string xxGetIP()
{
    local IPAddr zzIPAddr;
    local string zzIPStr;
    GetLocalIP(zzIpAddr);
    zzIPStr = IpAddrToString(zzIPAddr);
    if (InStr(zzIPStr, ":") != -1)
        zzIPStr = Left(zzIPStr, InStr(zzIPStr, ":"));
    return zzIPStr;
}

// =============================================================================
// xxUpdateDefs ~
// =============================================================================
function xxUpdateDefs()
{
    zzState      = 0;
    zzServerURI  = "utgl.unrealadmin.org";
    zzServerPath = "/ACE/latest.txt";
    xxDownload();
}

// =============================================================================
// xxGetDefs ~
// =============================================================================
function xxGetDefs(string zzPath)
{
    /*
    local string zzTmp;

    zzState      = 1;
    zzServerURI  = "utgl.unrealadmin.org";
    zzServerPath = zzPath;

    // Try to open log
    zzTmp = zzActor.zzPackageHelper.GetItemName("OPENBINARYLOG"@zzActor.zzDefsFileNew);
    if (zzTmp != "TRUE")
        xxHandleError(-4, "Can't write definitions file");
    else
        xxDownload();
    */
}

// =============================================================================
// xxGetWANIP ~
// =============================================================================
function xxGetWANIP()
{
    local int zzI;
    zzState = 2;
    zzLatest = "";

    zzServerNum++;
    if (zzServerNum < 10)
    {
        if (zzActor.WANQueryServer[zzServerNum] != "")
        {
            //zzActor.ACELog("Querying " $ zzActor.WANQueryServer[zzServerNum] $ " ...");

            if (InStr(zzActor.WANQueryServer[zzServerNum], "/") != -1)
            {
                zzServerURI  = Left(zzActor.WANQueryServer[zzServerNum], InStr(zzActor.WANQueryServer[zzServerNum], "/"));
                zzServerPath = Mid(zzActor.WANQueryServer[zzServerNum], InStr(zzActor.WANQueryServer[zzServerNum], "/"));
            }
            else
            {
                zzServerURI  = zzActor.WANQueryServer[zzServerNum];
                zzServerPath = "/";
            }

            xxDownload();
            return;
        }
        xxGetWANIP();
        return;
    }

    zzActor.ACELog("WARNING: ACE could not retrieve this server's WAN ip from any of the Query Servers.");
    zzActor.ACELog("WARNING: This server will NOT be accessible by clients outside the LAN.");
    Destroy();
}

// =============================================================================
// xxGotIP
// =============================================================================
function xxGotIP(string zzIP)
{
    local string zzTmp;
    local string zzChr;
    local int zzI;
    local int zzCount;
    local int zzExpecting; // 1 = ., 2 = num

    while (Len(zzIP) > 1 && InStr("0123456789.", Left(zzIP, 1)) == -1)
        zzIP = Mid(zzIP, 1);

    zzExpecting = 2;

    for (zzI = 0; zzI < Len(zzIP); ++zzI)
    {
        zzChr = Mid(zzIP, zzI, 1);

        if (zzExpecting == 1 && zzChr == ".")
        {
            zzCount++;
            zzExpecting = 2;
        }
        else if (zzExpecting == 2 && InStr("0123456789", zzChr) != -1)
        {
            zzCount++;
            zzExpecting = 1;
        }

        if (InStr("0123456789.", zzChr) != -1)
            zzTmp = zzTmp $ zzChr;
    }

    if (zzCount == 7)
    {
        zzActor.ACELog("- WAN IP Retrieved: " $ zzTmp);
        zzActor.zzPlayerManagerIPWAN   = zzTmp;
        zzActor.zzUpdatingWANIP = false;
        if (zzActor.bCacheWANIP)
        {
            zzActor.CachedWANIP = zzTmp;
            zzActor.SaveConfig();
        }
        Destroy();
    }
    else
    {
        zzActor.ACELog("Query Server " $ zzServerNum $ " (" $ zzActor.WANQueryServer[zzServerNum] $ ") returned an invalid WAN ip: " $ zzIP $ " . Trying next...");
        xxGetWANIP();
    }
}

// =============================================================================
// xxDownload ~
// =============================================================================
function xxDownload()
{
    zzHeaderRead = false;
    zzResponded  = false;
    zzStart      = zzActor.Level.TimeSeconds;
    Resolve(zzServerURI);
    SetTimer(30.0, false);
    Disable('Tick');
}

// =============================================================================
// xxClosed ~
// =============================================================================
function xxClosed()
{
    local string zzTmp;

    if (zzState == 1)
    {
        zzTmp = zzActor.zzPackageHelper.GetItemName("CLOSEBINARYLOG");
        if (zzTmp == "TRUE")
        {
            zzActor.ACELog("Successfully downloaded new definitions.");
            zzActor.ACELog("Downloaded "$zzBytes$" bytes in "$(zzActor.Level.TimeSeconds - zzStart)$" seconds ("
                $(zzBytes / 1024 / (zzActor.Level.TimeSeconds - zzStart))$" KByte/sec).");
        }
        Destroy();
    }
    else if (zzState == 0)
    {
        xxGotLatest(zzLatest);
    }
    else if (zzState == 2)
    {
        xxGotIP(zzLatest);
    }
}

// =============================================================================
// xxGotLatest ~
// =============================================================================
function xxGotLatest(string zzData)
{
    /*if (zzActor.xxGetTokenCount(zzData, ":::") == 2)
    {
        if (zzActor.xxGetToken(zzData, ":::", 0) != zzActor.zzDefinitionsFile.GetItemName("GETVERSION"))
        {
            zzActor.ACELog("A new version of the ACE File Definitions Database is available.");
            zzActor.ACELog("Current Version:"@zzActor.zzDefinitionsFile.GetItemName("GETVERSION"));
            zzActor.ACELog("New Version:"@zzActor.xxGetToken(zzData, ":::", 0));
            zzActor.ACELog("ACE is now auto-updating.");
            xxGetDefs(zzActor.xxGetToken(zzData, ":::", 1));
        }
        else
        {
            Destroy();
        }
    } */
}

// =============================================================================
// PostBeginPlay ~
// =============================================================================
function PostBeginPlay()
{
    zzCF      = Chr(13)$Chr(10);
    zzTicking = false;
    Super.PostBeginPlay();
}

// =============================================================================
// Destroyed ~ Try to clear remaining data
// =============================================================================
event Destroyed()
{
    local byte zzB[255], zzI;

    while (IsDataPending() && zzI < 30)
    {
        zzI++;
        ReadBinary(255, zzB);
    }

    if (IsConnected())
        Close();
}

// =============================================================================
// xxHandleError ~
// =============================================================================
function xxHandleError(int zzCode, string zzDesc)
{
    if (zzState == 2)
    {
        zzActor.ACELog("Query Failed - Code: "$zzCode$" - Desc: "$zzDesc);
        xxGetWANIP();
    }
    else
        zzActor.ACELog("Update Failed - Code: "$zzCode$" - Desc: "$zzDesc);
}

// =============================================================================
// ResolveFailed ~
// =============================================================================
function ResolveFailed()
{
    xxHandleError(-3, "Resolve Failed");
}

// =============================================================================
// Resolved ~
// =============================================================================
function Resolved( IpAddr Addr )
{
    Addr.Port=80;

    if (Addr.Addr==0)
        xxHandleError(-3, "Resolve Failed");
    if( BindPort() <= 0)
    {
        xxHandleError(-2, "Couldn't bind port");
        return;
    }

    SetTimer(20.0, false);
    Open(Addr);
}

// =============================================================================
// Opened ~
// =============================================================================
event Opened()
{
    SendText("GET"@zzServerPath@"HTTP/1.1"$zzcf$"Connection: close"$zzcf$"Host:"@zzServerURI$":80"$zzcf$zzcf);
    LinkMode    = MODE_Binary;
    ReceiveMode = RMODE_Manual;
    zzTicking   = true;
    enable('tick');
}

// =============================================================================
// Closed ~
// =============================================================================
event Closed()
{
    xxClosed();
}

// =============================================================================
// ReceivedLine ~ Parse rest of http header
// =============================================================================
event ReceivedLine( string zzLine )
{
    local int zzRes;

    if (!zzResponded)
    {
        zzRes       = Int(Mid(zzLine, InStr(zzLine, " ") + 1));
        zzResponded = true;
        if(zzRes != 200) xxHandleError(zzres, "HTTP Error");

        return;
    }

    if (zzLine == "")
    {
        zzHeaderRead=true;
        return;
    }

    if (left(zzLine,16) == "Content-Length: ")
        zzSize = int(mid(zzLine,16));
}

// =============================================================================
// xxAddToLine ~ Gathering the http header into one line
// =============================================================================
function xxAddToLine (int zzCount, byte zzB[255])
{
    local int i, j;

    for (i = 0; i < zzCount; i++)
    {
        if (zzHeaderRead)
        {
            while (i < zzCount)
            {
                zzB[j] = zzB[i];
                j++;
                i++;
            }

            ReceivedBinary(j, zzB);
            return;
        }

        if (zzB[i] == 10 && asc(right(zzLine,1)) == 13)
        {
            ReceivedLine(left(zzLine,len(zzline)-1));
            zzLine="";
            continue;
        }

        zzLine=zzLine$Chr(zzB[i]);
    }
}

// =============================================================================
// Tick ~ Process buffer
// =============================================================================
function Tick(float Delta)
{
    local byte B[255];
    local int i;

    if (!zzTicking)
        return;

    if (ReceiveMode != RMODE_Manual || LinkState != STATE_Connected)
        return;

    while (IsDataPending())
    {
        i = ReadBinary(255,B);

        if (i<=0)
            return;

        if (!zzHeaderRead)
        {
            xxAddToLine(i,B);
            continue;
        }

        ReceivedBinary(i,B);
    }
}

// =============================================================================
// xxThreePad
// =============================================================================
function string xxThreePad(byte B)
{
    local string zzTmp;
    zzTmp = "" $ B;
    while (Len(zzTmp) < 3)
        zzTmp = "0"$zzTmp;
    return zzTmp;
}

// =============================================================================
// ReceivedBinary ~ Convert
// =============================================================================
event ReceivedBinary( int Count, byte B[255] )
{
    local string zzStr;
    local int zzI;

    if (zzState == 1)
    {
        while (zzI < Count)
        {
            if (Len(zzStr) >= 128)
            {
                zzActor.zzPackageHelper.GetItemName("LOGBINARY"@zzStr);
                zzStr = "";
            }

            zzStr = zzStr$xxThreePad(B[zzI]);
            zzI++;
        }

        if (Len(zzStr) > 0)
            zzActor.zzPackageHelper.GetItemName("LOGBINARY"@zzStr);

        zzBytes += Count;
        SetTimer(60.0, false);
    }
    else
    {
        for (zzI = 0; zzI < Count; ++zzI)
            zzLatest = zzLatest$chr(B[zzI]);
    }
}

// =============================================================================
// Timer ~
// =============================================================================
function Timer()
{
    xxHandleError(-1, "Timed out");
}

// =============================================================================
// defaultproperties
// =============================================================================
defaultproperties
{
    ReceiveMode=RMODE_Event
    LinkMode=MODE_Binary
}

