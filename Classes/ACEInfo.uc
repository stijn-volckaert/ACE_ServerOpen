// =============================================================================
// AntiCheatEngine - (c) 2009-2016 AnthraX
// =============================================================================
class ACEInfo extends Actor;

var string ModName;             // name of the mod (eg: UTDCv21)
var string ModDLLName;          // name of the mod's DLL file (eg: UTDCv21.dll)
var string ModSOName;           // Name of the mod's SO file (if this is empty, the native is just disabled on linux clients)
var string ModDLLLoaderName;    // name of the mod's dll loader package (eg: UTDCv21DLL.u)
var string ModSOLoaderName;     // name of the mod's so loader package (eg: NPLoaderLLS.u)
var string ModPkgDescriptor;    // for multiple versions of the same dll in one package
var string ModLicense;          // license agreement for this mod
var string ModAuthor;           // name of the mod's author (eg: Troublesome)
var string ModDesc;             // Description of the mod (eg: Unreal Tournament Damage Control v2.1 Anti-cheat)
var string ModDLLURL;           // URL for manual downloading of the DLL file (eg: http://utgl.unrealadmin.org/UTDCv21.dll)
var string ModSOURL;            // URL for manual downloading of the SO file (eg: http://utgl.unrealadmin.org/NPLoader/NPLoaderLLS.u)
var string ConflictingClasses;  // InfoClasses of the mods that shouldn't run alongside this mod
var string ConflictingActors;   // Actors that should be removed for this mod to run
var string ConflictingPackages; // Packages that should be removed for this mod to run
var string RequiredActors;      // Actors needed for this mod to run
var string RequiredPackages;    // Packages needed for this mod to run (mod loader doesn't need to be included but it may be)

// =============================================================================
// PostBeginPlay ~ Initialize all important variables
// =============================================================================
function PostBeginPlay()
{
    ModName             = "ACE@ACESHORTVERLOWER@";
    ModDLLName          = "ACE@ACESHORTVERLOWER@_C.dll";
    ModDLLLoaderName    = "ACE@ACESHORTVERLOWER@_Cdll.u";
    ModPkgDescriptor    = "A:5:-C:5:SSE,SSE2-E:5:SSE,SSE2,AVX,AVX2";
    ModLicense          = "IACE@ACESHORTMAJORVERLOWER@.ACEEULA";
    ModAuthor           = "AnthraX";
    ModDesc             = "AntiCheatEngine for Unreal Tournament 99";
    ModDLLURL           = "http://utgl.unrealadmin.org/ACE/@ACESHORTMAJORVERLOWER@/ACE@ACESHORTVERLOWER@_C.dll";
    ConflictingClasses  = "ACEv06_S.ACEInfo,"
                        $ "ACEv06b_S.ACEInfo,"
                        $ "ACEv06c_S.ACEInfo,"
                        $ "ACEv06d_S.ACEInfo,"
                        $ "ACEv06e_S.ACEInfo,"
                        $ "ACEv06f_S.ACEInfo,"
                        $ "ACEv06g_S.ACEInfo,"
                        $ "ACEv06h_S.ACEInfo,"
                        $ "ACEv06i_S.ACEInfo,"
                        $ "ACEv06j_S.ACEInfo,"
                        $ "ACEv06k_S.ACEInfo,"
                        $ "ACEv06l_S.ACEInfo,"
                        $ "ACEv06m_S.ACEInfo,"
                        $ "ACEv06n_S.ACEInfo,"
                        $ "ACEv06p_S.ACEInfo,"
                        $ "ACEv06q_S.ACEInfo,"
                        $ "ACEv07_S.ACEInfo,"
                        $ "ACEv07b_S.ACEInfo,"
                        $ "ACEv07c_S.ACEInfo,"
                        $ "ACEv07d_S.ACEInfo,"
                        $ "ACEv07e_S.ACEInfo,"
                        $ "ACEv07f_S.ACEInfo,"
                        $ "ACEv08_S.ACEInfo,"
                        $ "ACEv08b_S.ACEInfo,"
                        $ "ACEv08c_S.ACEInfo,"
                        $ "ACEv08d_S.ACEInfo,"
                        $ "ACEv08e_S.ACEInfo,"
                        $ "ACEv08f_S.ACEInfo,"
                        $ "ACEv08g_S.ACEInfo,"
                        $ "ACEv08h_S.ACEInfo,"
                        $ "ACEv09_S.ACEInfo,"
                        $ "ACEv09b_S.ACEInfo,"
                        $ "ACEv09c_S.ACEInfo,"
						$ "ACEv09d_S.ACEInfo,"
						$ "ACEv09e_S.ACEInfo,"
						$ "ACEv10_S.ACEInfo,"
						$ "ACEv10b_S.ACEInfo,"
						$ "ACEv10c_S.ACEInfo,"
                        $ "";
    ConflictingActors   = "ACEv06h_S.ACEActor,ACEv06h_EH.ACEEventActor,"
                        $ "ACEv06i_S.ACEActor,ACEv06i_EH.ACEEventActor,"
                        $ "ACEv06j_S.ACEActor,ACEv06j_EH.ACEEventActor,"
                        $ "ACEv06k_S.ACEActor,ACEv06k_EH.ACEEventActor,"
                        $ "ACEv06l_S.ACEActor,ACEv06l_EH.ACEEventActor,"
                        $ "ACEv06m_S.ACEActor,ACEv06m_EH.ACEEventActor,"
                        $ "ACEv06n_S.ACEActor,ACEv06n_EH.ACEEventActor,"
                        $ "ACEv06p_S.ACEActor,ACEv06p_EH.ACEEventActor,"
                        $ "ACEv06q_S.ACEActor,ACEv06q_EH.ACEEventActor,"
                        $ "ACEv07_S.ACEActor,ACEv07_EH.ACEEventActor,"
                        $ "ACEv07b_S.ACEActor,ACEv07b_EH.ACEEventActor,"
                        $ "ACEv07c_S.ACEActor,ACEv07c_EH.ACEEventActor,"
                        $ "ACEv07d_S.ACEActor,ACEv07d_EH.ACEEventActor,"
                        $ "ACEv07e_S.ACEActor,ACEv07e_EH.ACEEventActor,"
                        $ "ACEv07f_S.ACEActor,ACEv07f_EH.ACEEventActor,"
                        $ "ACEv08_S.ACEActor,ACEv08_EH.ACEEventActor,"
                        $ "ACEv08b_S.ACEActor,ACEv08b_EH.ACEEventActor,"
                        $ "ACEv08c_S.ACEActor,ACEv08c_EH.ACEEventActor,"
                        $ "ACEv08d_S.ACEActor,ACEv08d_EH.ACEEventActor,"
                        $ "ACEv08e_S.ACEActor,ACEv08e_EH.ACEEventActor,"
                        $ "ACEv08f_S.ACEActor,ACEv08f_EH.ACEEventActor,"
                        $ "ACEv08g_S.ACEActor,ACEv08g_EH.ACEEventActor,"
                        $ "ACEv08h_S.ACEActor,ACEv08h_EH.ACEEventActor,"
                        $ "ACEv09_S.ACEActor,ACEv09_EH.ACEEventActor,"
                        $ "ACEv09b_S.ACEActor,ACEv09b_EH.ACEEventActor,"
                        $ "ACEv09c_S.ACEActor,ACEv09c_EH.ACEEventActor,"
                        $ "ACEv09d_S.ACEActor,ACEv09d_EH.ACEEventActor,"
                        $ "ACEv09e_S.ACEActor,ACEv09e_EH.ACEEventActor,"
                        $ "ACEv10_S.ACEActor,ACEv10_EH.ACEEventActor,"
						$ "ACEv10b_S.ACEActor,ACEv10b_EH.ACEEventActor,"
						$ "ACEv10c_S.ACEActor,ACEv10c_EH.ACEEventActor,"
                        $ "NPLoader_v14.NPLActor,"
                        $ "NPLoader_v15.NPLActor,"
                        $ "NPLoader_v15b.NPLActor,"
                        $ "NPLoader_v15c.NPLActor,"
                        $ "NPLoader_v15d.NPLActor,"
                        $ "NPLoader_v15e.NPLActor,"
                        $ "NPLoader_v16.NPLActor,"
                        $ "NPLoader_v16b.NPLActor,"
                        $ "NPLoader_v16c.NPLActor,"
                        $ "";
    ConflictingPackages = "IACEv06h,ACEv06h_C,ACEv06h_Cdll,"
                        $ "IACEv06i,ACEv06i_C,ACEv06i_Cdll,"
                        $ "IACEv06j,ACEv06j_C,ACEv06j_Cdll,"
                        $ "IACEv06k,ACEv06k_C,ACEv06k_Cdll,"
                        $ "IACEv06l,ACEv06l_C,ACEv06l_Cdll,"
                        $ "IACEv06m,ACEv06m_C,ACEv06m_Cdll,"
                        $ "IACEv06n,ACEv06n_C,ACEv06n_Cdll,"
                        $ "IACEv06p,ACEv06p_C,ACEv06p_Cdll,"
                        $ "IACEv06q,ACEv06q_C,ACEv06q_Cdll,"
                        $ "ACEv07_C,ACEv07_Cdll,"
                        $ "ACEv07b_C,ACEv07b_Cdll,"
                        $ "ACEv07c_C,ACEv07c_Cdll,"
                        $ "ACEv07d_C,ACEv07d_Cdll,"
                        $ "ACEv07e_C,ACEv07e_Cdll,"
                        $ "IACEv07,ACEv07f_C,ACEv07f_Cdll,"
                        $ "ACEv08_C,ACEv08_Cdll,"
                        $ "IACEv08,ACEv08b_C,ACEv08b_Cdll,"
                        $ "ACEv08c_C,ACEv08c_Cdll,"
                        $ "ACEv08d_C,ACEv08d_Cdll,"
                        $ "ACEv08e_C,ACEv08e_Cdll,"
                        $ "ACEv08f_C,ACEv08f_Cdll,"
                        $ "ACEv08g_C,ACEv08g_Cdll,"
                        $ "IACEv08c,ACEv08h_C,ACEv08h_Cdll,"
                        $ "ACEv09_C,ACEv09_Cdll,"
                        $ "ACEv09b_C,ACEv09b_Cdll,"
                        $ "ACEv09c_C,ACEv09c_Cdll,"
                        $ "ACEv09d_C,ACEv09d_Cdll,"
                        $ "IACEv09,ACEv09e_C,ACEv09e_Cdll,"
                        $ "ACEv10_C,ACEv10_Cdll,"
						$ "ACEv10b_C,ACEv10b_Cdll,"
						$ "ACEv10c_C,ACEv10c_Cdll,"
                        $ "NPLoader_v14,NPLoaderLLU_v14,NPLoaderLLD_v14,NPLoaderLLS_v14,"
                        $ "NPLoader_v15,NPLoaderLLU_v15,NPLoaderLLD_v15,NPLoaderLLS_v15,"
                        $ "NPLoader_v15b,NPLoaderLLU_v15b,NPLoaderLLD_v15b,NPLoaderLLS_v15b,"
                        $ "NPLoader_v15c,NPLoaderLLU_v15c,NPLoaderLLD_v15c,NPLoaderLLS_v15c,"
                        $ "NPLoader_v15d,NPLoaderLLU_v15d,NPLoaderLLD_v15d,NPLoaderLLS_v15d,"
                        $ "NPLoader_v15e,NPLoaderLLU_v15e,NPLoaderLLD_v15e,NPLoaderLLS_v15e,"
                        $ "NPLoader_v16,NPLoaderLLU_v16,NPLoaderLLD_v16,NPLoaderLLS_v16,"
                        $ "NPLoader_v16b,NPLoaderLLU_v16b,NPLoaderLLD_v16b,NPLoaderLLS_v16b,"
                        $ "NPLoader_v16c,NPLoaderLLU_v16c,NPLoaderLLD_v16c,NPLoaderLLS_v16c,"
                        $ "";
    RequiredActors      = "ACE@ACESHORTVERLOWER@_S.ACEActor,ACE@ACESHORTVERLOWER@_EH.ACEEventActor";
    RequiredPackages    = "IACE@ACESHORTMAJORVERLOWER@,ACE@ACESHORTVERLOWER@_C,ACE@ACESHORTVERLOWER@_Cdll";
}

// =============================================================================
// GetItemName ~ This function is used to talk with NPLoader (do NOT EDIT!)
// =============================================================================
function string GetItemName(string FullName)
{
    switch(CAPS(FullName))
    {
        case "GETMODNAME":
            return ModName;
        case "GETMODDLLNAME":
            return ModDLLName;
        case "GETMODDLLLOADERNAME":
            return ModDLLLoaderName;
        case "GETMODAUTHOR":
            return ModAuthor;
        case "GETMODDESC":
            return ModDesc;
        case "GETMODDLLURL":
            return ModDLLURL;
        case "GETMODSONAME":
            return ModSOName;
        case "GETMODSOLOADERNAME":
            return ModSOLoaderName;
        case "GETMODSOURL":
            return ModSOURL;
        case "GETMODPKGDESC":
            return ModPkgDescriptor;
        case "GETMODLICENSECLASS":
            return ModLicense;
        case "GETCONFLICTINGCLASSES":
            return ConflictingClasses;
        case "GETCONFLICTINGACTORS":
            return ConflictingActors;
        case "GETCONFLICTINGPACKAGES":
            return ConflictingPackages;
        case "GETREQUIREDACTORS":
            return RequiredActors;
        case "GETREQUIREDPACKAGES":
            return RequiredPackages;
        case "GETINFOVERSION":
            return "3";
        default:
            return "";
    }
}

// =============================================================================
// defaultproperties ~ do not remove the bHidden flag or an eaglehead will show
// in the middle of the map
// =============================================================================
defaultproperties
{
    bHidden=True
}
