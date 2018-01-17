// =============================================================================
// AntiCheatEngine - (c) 2009-2016 AnthraX
// =============================================================================
class ACEMutator extends Mutator;

// =============================================================================
// Global Variables
// =============================================================================
var ACEActor zzACEActor;

// =============================================================================
// Mutate ~
// =============================================================================
function Mutate(string MutateString, PlayerPawn Sender)
{
    local string zzMessage;
    local string zzData1, zzData2;
    local string zzTmp;
    local IACECheck zzCheck;
    local ACEReplicationInfo zzRI;
    local bool zzAdmin;
    local bool zzFound;
    local int zzI;
    local float zzScale;

    if (zzACEActor.xxGetToken(MutateString, " ", 0) ~= "ACE")
    {
        zzMessage = zzACEActor.xxGetToken(MutateString, " ", 1);
        zzI       = zzACEActor.xxGetTokenCount(MutateString, " ");

        if (zzI >= 3)
            zzData1 = zzACEActor.xxGetToken(MutateString, " ", 2);
        if (zzI >= 4)
            zzData2 = zzACEActor.xxGetToken(MutateString, " ", 3);

        switch(CAPS(zzMessage))
        {
            case "HELP":
                if (zzData1 == "")
                {
                    Sender.ClientMessage("Currently supported commands:");
                    Sender.ClientMessage("- ACE Status: Shows details about the status of ACE and the version of the whitelist");
                    Sender.ClientMessage("- ACE PlayerList <ACE AdminPass (optional)>: Shows a list of players that are currently being checked by ACE");
                    Sender.ClientMessage("- ACE SShot <PlayerID> <ACE AdminPass (optional)>: Attempts to create a screenshot for the specified player");
                    Sender.ClientMessage("- ACE CrosshairScale <Scale>: Overrides the default crosshair scale. If Scale is -1.0 or auto the crosshair will dynamically scale with your resolution. If it's set to a positive number the scale will be fixed");
                    Sender.ClientMessage("- ACE CompatToggle: Toggles ACE compatibility mode. Use this only if you're experiencing severe performance problems on ACE servers (not recommended!)");
                    Sender.ClientMessage("- ACE SFToggle: Toggles the ACE soundfix.");
                    Sender.ClientMessage("- ACE HighPerfToggle: Toggles ACE High Performance mode. Improves stability of the framerate. Only for high end pcs.");
                    Sender.ClientMessage("- ACE SetDemoStatus <Status>: Controls the demo status display. Type mutate ace help demostatus for an overview of supported options.");
                    Sender.ClientMessage("- ACE HideDemoStatus: Toggle off the demo status display.");
                    Sender.ClientMessage("- ACE PlayerSettings: Shows an overview of your settings.");
                    Sender.ClientMessage("- ACE FileListInfo: Shows information about the FileList on the server.");
                    Sender.ClientMessage("- ACE ServerSettingsInfo: Shows information about the server's ACE settings.");
                }
                else if (zzData1 ~= "demostatus")
                {
                    Sender.ClientMessage("ACE Demo Status Display:");
                    Sender.ClientMessage("- Syntax: mutate ace setdemostatus <status>");
                    Sender.ClientMessage("- Supported Statusses:");
                    Sender.ClientMessage("    * 0 (default): ALWAYS show the demo status in 'Recording: <filename> <time>' format");
                    Sender.ClientMessage("    * 1: ALWAYS show the demo status in 'Recording: <YES/NO> format'");
                    Sender.ClientMessage("    * 2: Show demo status WHEN RECORDING ONLY in 'Recording: <filename> <time>' format");
                    Sender.ClientMessage("    * 3: Show demo status WHEN RECORDING ONLY in 'Recording: <YES/NO> format'");
                    Sender.ClientMessage("    * 4: HIDE demo status display");
                }
                break;

            case "STATUS":
                Sender.ClientMessage("ACE Version    : " $ zzACEActor.ACEVersion);
                Sender.ClientMessage("ACE Crosshair Scaling override allowed : " $ zzACEActor.bAllowCrosshairScaling);
                break;

            case "PLAYERLIST":

                if (Sender.bAdmin)
                    zzAdmin = true;

                if (!zzAdmin && zzData1 != "")
                {
                    if (zzData1 ~= zzACEActor.AdminPass)
                        zzAdmin = true;
                    else
                        Sender.ClientMessage("Incorrect Password. Printing standard info only");
                }

                if (!zzAdmin)
                    Sender.ClientMessage("Currently checked players:");
                else
                    Sender.ClientMessage("Currently checked players (extended):");

                foreach Level.AllActors(class'IACECheck', zzCheck)
                {
                    if (zzCheck.Owner != none)
                    {
                        zzTmp = "" $ zzCheck.PlayerID $ " - " $ zzCheck.PlayerName;

                        if (zzAdmin)
                        {
                            zzTmp = zzTmp $ " - " $ zzCheck.PlayerIP;
                            if (zzCheck.bTunnel)
                                zzTmp = zzTmp $ " - Real IP: " $ zzCheck.RealIP;
                        }

                        Sender.ClientMessage(zzTmp);
                    }
                }

                break;

            case "SSHOT":

                if (Sender.bAdmin)
                    zzAdmin = true;

                if (!zzAdmin)
                {
                    if (zzData2 != "")
                    {
                        if (zzData2 ~= zzACEActor.AdminPass)
                            zzAdmin = true;
                        else
                            Sender.ClientMessage("Incorrect Password.");
                    }
                    else
                    {
                        Sender.ClientMessage("You need to log in or use the password to execute this command");
                    }
                }

                if (zzAdmin)
                {
                    if (zzData1 == "")
                    {
                        Sender.ClientMessage("PlayerID not specified");
                    }
                    else
                    {
                        zzI = int(zzData1);

                        foreach Level.AllActors(class'IACECheck', zzCheck)
                        {
                            if (zzCheck.PlayerID == zzI && zzCheck.Owner != None)
                            {
                                zzACEActor.xxCreateScreenshot(Sender, PlayerPawn(zzCheck.Owner));
                                zzFound = true;
                                Sender.ClientMessage("Screenshot Requested for Player: " $ zzI $ " - " $ zzCheck.PlayerName);
                                break;
                            }
                        }

                        if (!zzFound)
                            Sender.ClientMessage("Player not found");
                    }
                }

                break;

            case "CROSSHAIRSCALE":

                if (!zzACEActor.bAllowCrosshairScaling)
                {
                    Sender.ClientMessage("Crosshair Scaling is not allowed on this server!");
                }
                else
                {
                    foreach Level.AllActors(class'IACECheck', zzCheck)
                    {
                        if (zzCheck.Owner == Sender)
                        {
                            if (zzData1 ~= "auto")
                                zzScale = -1.0;
                            else
                                zzScale = float(zzData1);

                            if (zzScale == 0.0)
                            {
                                Sender.ClientMessage("Invalid Scale: " $ zzScale);
                            }
                            else
                            {
                                zzCheck.SetPlayerCrosshairScale(zzScale);
                            }
                            break;
                        }
                    }
                }

                break;

            case "COMPATTOGGLE":

                foreach Level.AllActors(class'IACECheck', zzCheck)
                {
                    if (zzCheck.Owner == Sender)
                    {
                        zzCheck.ToggleCompatibilityMode();
                        break;
                    }
                }

                break;

            case "SFTOGGLE":

                foreach Level.AllActors(class'IACECheck', zzCheck)
                {
                    if (zzCheck.Owner == Sender)
                    {
                        zzCheck.ToggleSoundFix();
                        break;
                    }
                }

                break;

            case "HIGHPERFTOGGLE":

                foreach Level.AllActors(class'IACECheck', zzCheck)
                {
                    if (zzCheck.Owner == Sender)
                    {
                        zzCheck.TogglePerformanceMode();
                        break;
                    }
                }

                break;

            case "SETDEMOSTATUS":

                foreach Level.AllActors(class'IACECheck', zzCheck)
                {
                    if (zzCheck.Owner == Sender)
                    {
                        zzCheck.SetDemoStatus(int(zzData1));
                        break;
                    }
                }

                break;

            case "HIDEDEMOSTATUS":

                foreach Level.AllActors(class'IACECheck', zzCheck)
                {
                    if (zzCheck.Owner == Sender)
                    {
                        zzCheck.SetDemoStatus(4);
                        break;
                    }
                }

                break;

            case "PLAYERSETTINGS":

                foreach Level.AllActors(class'IACECheck', zzCheck)
                {
                    if (zzCheck.Owner == Sender)
                    {
                        zzCheck.ViewSettings();
                        break;
                    }
                }

                break;

            case "FILELISTINFO":

                foreach Level.AllActors(class'IACECheck', zzCheck)
                {
                    if (zzCheck.Owner == Sender)
                    {
                        zzRI = ACEReplicationInfo(zzCheck);
                        zzRI.ShowFileListInfo();
                        break;
                    }
                }

                break;

            case "SERVERSETTINGSINFO":

                Sender.ClientMessage("ACE Strict System Library Checking: "$zzACEActor.bStrictSystemLibraryChecks);

                break;
        }
    }
    else
    {
        Super.Mutate(MutateString, Sender);
    }
}
